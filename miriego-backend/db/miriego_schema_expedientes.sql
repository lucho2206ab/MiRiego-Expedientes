-- ============================================================================
-- MiRiego — Arquitectura de Base de Datos
-- Módulo: Expedientes / Notas / Pases (reemplazo del sistema Progress 9.1D)
-- Motor: PostgreSQL 14+
-- ============================================================================
-- Notas de diseño:
-- 1. Usa el mismo schema "miriego" que reclamos, para poder referenciar
--    usuarios/sectores desde ambos módulos si hace falta más adelante.
-- 2. "sector_actual_id" en expedientes es la ubicación administrativa
--    vigente. Cada vez que se mueve, se genera un registro en "pases"
--    y se actualiza sector_actual_id (igual que hacía el CRUD en Progress,
--    pero acá queda historial completo en vez de solo el estado actual).
-- 3. gde_numero / infogov_numero son nullable: permiten vincular un
--    expediente de MiRiego con su equivalente en GDE o en Infogov cuando
--    corresponda, sin depender de que la integración por API ya exista
--    (por ahora se cargan a mano).
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS miriego;
SET search_path TO miriego, public;

-- ============================================================================
-- 1. TIPOS ENUM
-- ============================================================================

CREATE TYPE estado_expediente AS ENUM (
    'iniciado',
    'en_tramite',
    'pase_pendiente',   -- se envió pero el sector destino no confirmó recepción
    'pendiente_firma',
    'observado',        -- devuelto para corrección
    'resuelto',
    'archivado',
    'anulado'
);

CREATE TYPE estado_pase AS ENUM (
    'enviado',
    'recibido',
    'rechazado'         -- el sector destino lo devuelve sin tomarlo
);

-- ============================================================================
-- 2. SECTORES (dependencias internas del organismo)
-- ============================================================================

CREATE TABLE sectores (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(150) NOT NULL UNIQUE,  -- ej: "Mesa de Entradas", "Legales", "Inspección de Cauces"
    descripcion     TEXT,
    sector_padre_id INTEGER REFERENCES sectores(id),  -- para sub-áreas, opcional
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 3. TIPOS DE EXPEDIENTE (catálogo configurable)
-- ============================================================================

CREATE TABLE tipos_expediente (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(150) NOT NULL UNIQUE,  -- ej: "Solicitud de reempadronamiento", "Reclamo formal", "Resolución interna"
    descripcion     TEXT,
    activo          BOOLEAN NOT NULL DEFAULT TRUE
);

-- ============================================================================
-- 4. EXPEDIENTES
-- ============================================================================

CREATE TABLE expedientes (
    id                      SERIAL PRIMARY KEY,
    numero_expediente       VARCHAR(40) NOT NULL UNIQUE,  -- numeración interna MiRiego, ej: EXP-2026-000045
    tipo_id                 INTEGER NOT NULL REFERENCES tipos_expediente(id),

    asunto                  VARCHAR(250) NOT NULL,
    descripcion             TEXT,

    -- Quién lo inicia: puede ser un regante (con o sin CCPP) o un
    -- usuario interno. Se guarda como texto libre + referencia opcional
    -- para no obligar a que todo iniciador tenga cuenta en el sistema.
    iniciador_nombre        VARCHAR(150) NOT NULL,
    iniciador_dni_cuit      VARCHAR(20),
    iniciador_cc            VARCHAR(20),  -- código de cauce
    iniciador_pp            VARCHAR(20),  -- padrón de propietarios
    regante_id              INTEGER,  -- FK lógica a miriego.regantes(id) del módulo de reclamos, sin FK física
                                      -- para no acoplar ambos módulos de entrada; se puede endurecer después.

    sector_actual_id        INTEGER NOT NULL REFERENCES sectores(id),
    estado                  estado_expediente NOT NULL DEFAULT 'iniciado',

    -- Vínculos externos (se cargan a mano hasta tener API real)
    gde_numero              VARCHAR(60),
    infogov_numero          VARCHAR(60),

    fecha_inicio            TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_ultima_actualizacion TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_resolucion        TIMESTAMPTZ,
    fecha_archivo           TIMESTAMPTZ,
    fecha_vencimiento       TIMESTAMPTZ,

    creado_por              INTEGER  -- FK lógica a usuarios(id) del módulo de reclamos
);

CREATE INDEX idx_expedientes_sector_actual ON expedientes(sector_actual_id);
CREATE INDEX idx_expedientes_estado ON expedientes(estado);
CREATE INDEX idx_expedientes_tipo ON expedientes(tipo_id);
CREATE INDEX idx_expedientes_fecha_inicio ON expedientes(fecha_inicio);

-- ============================================================================
-- 5. PASES (movimientos entre sectores — reemplaza el CRUD de movimientos
--    que hoy hace el sistema Progress)
-- ============================================================================

CREATE TABLE pases (
    id                  SERIAL PRIMARY KEY,
    expediente_id       INTEGER NOT NULL REFERENCES expedientes(id) ON DELETE CASCADE,
    sector_origen_id    INTEGER NOT NULL REFERENCES sectores(id),
    sector_destino_id   INTEGER NOT NULL REFERENCES sectores(id),
    usuario_id          INTEGER,  -- quién generó el pase (FK lógica a usuarios)
    motivo              VARCHAR(250),
    observaciones       TEXT,
    estado              estado_pase NOT NULL DEFAULT 'enviado',
    fecha_envio         TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_recepcion     TIMESTAMPTZ,  -- se completa cuando el sector destino lo confirma
    fecha_vencimiento   TIMESTAMPTZ
);

CREATE INDEX idx_pases_expediente ON pases(expediente_id);
CREATE INDEX idx_pases_sector_destino ON pases(sector_destino_id) WHERE estado = 'enviado';

-- ============================================================================
-- 6. NOTAS (observaciones internas, no implican movimiento de sector)
-- ============================================================================

CREATE TABLE notas (
    id                  SERIAL PRIMARY KEY,
    expediente_id       INTEGER NOT NULL REFERENCES expedientes(id) ON DELETE CASCADE,
    sector_id           INTEGER NOT NULL REFERENCES sectores(id),
    usuario_id          INTEGER,  -- FK lógica a usuarios
    contenido           TEXT NOT NULL,
    es_interna          BOOLEAN NOT NULL DEFAULT TRUE,  -- FALSE = visible para el iniciador externo
    fecha               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notas_expediente ON notas(expediente_id);

-- ============================================================================
-- 7. ADJUNTOS
-- ============================================================================

CREATE TABLE expediente_adjuntos (
    id              SERIAL PRIMARY KEY,
    expediente_id   INTEGER NOT NULL REFERENCES expedientes(id) ON DELETE CASCADE,
    archivo_url     TEXT NOT NULL,
    tipo_archivo    VARCHAR(50),
    descripcion     VARCHAR(255),
    fecha           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_expediente_adjuntos_expediente ON expediente_adjuntos(expediente_id);

-- ============================================================================
-- 8. HISTORIAL (auditoría de cambios de estado y sector)
-- ============================================================================

CREATE TABLE expediente_historial (
    id                  SERIAL PRIMARY KEY,
    expediente_id       INTEGER NOT NULL REFERENCES expedientes(id) ON DELETE CASCADE,
    usuario_id          INTEGER,
    accion              VARCHAR(100) NOT NULL,  -- "creacion", "pase", "cambio_estado", "nota"
    estado_anterior     estado_expediente,
    estado_nuevo        estado_expediente,
    sector_anterior_id  INTEGER REFERENCES sectores(id),
    sector_nuevo_id     INTEGER REFERENCES sectores(id),
    observacion         TEXT,
    fecha               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_expediente_historial_expediente ON expediente_historial(expediente_id);

-- ============================================================================
-- 9. TRIGGERS: actualizar sector_actual_id y estado del expediente al
--    registrar un pase, y dejar rastro en el historial.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_aplicar_pase()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.subsector_mesa_entradas IN ('Archivo Mesa de Entradas', 'Archivo Deposito') THEN
        UPDATE expedientes
            SET sector_actual_id = NEW.sector_destino_id,
                estado = 'archivado',
                fecha_archivo = now(),
                fecha_ultima_actualizacion = now()
            WHERE id = NEW.expediente_id;

        INSERT INTO expediente_historial (
            expediente_id, usuario_id, accion,
            estado_anterior, estado_nuevo,
            sector_anterior_id, sector_nuevo_id, observacion
        ) VALUES (
            NEW.expediente_id, NEW.usuario_id, 'pase',
            NULL, 'archivado',
            NEW.sector_origen_id, NEW.sector_destino_id, NEW.motivo
        );
    ELSE
        UPDATE expedientes
            SET sector_actual_id = NEW.sector_destino_id,
                estado = 'en_tramite',
                fecha_ultima_actualizacion = now()
            WHERE id = NEW.expediente_id;

        INSERT INTO expediente_historial (
            expediente_id, usuario_id, accion,
            estado_anterior, estado_nuevo,
            sector_anterior_id, sector_nuevo_id, observacion
        ) VALUES (
            NEW.expediente_id, NEW.usuario_id, 'pase',
            NULL, 'en_tramite',
            NEW.sector_origen_id, NEW.sector_destino_id, NEW.motivo
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_aplicar_pase
    AFTER INSERT ON pases
    FOR EACH ROW
    EXECUTE FUNCTION fn_aplicar_pase();

-- NOTA: se removió el trigger de "confirmación de recepción" (que dejaba
-- el expediente en estado intermedio 'pase_pendiente' hasta que el
-- sector destino confirmaba). Por ahora el pase se aplica directo.
-- Si en el futuro lo necesitan, se puede reintroducir una función tipo
-- fn_confirmar_recepcion_pase() con un trigger BEFORE UPDATE ON pases.

-- ============================================================================
-- 10. DATOS SEMILLA MÍNIMOS — ajustar con la estructura real de sectores
-- ============================================================================

INSERT INTO sectores (nombre, descripcion) VALUES
    ('Mesa de Entradas', 'Recepción y carga inicial de expedientes'),
    ('Administración', 'Gestión administrativa general'),
    ('Contabilidad', 'Gestión contable'),
    ('Legales', 'Revisión y dictamen legal'),
    ('Inspección de Cauces', 'Intervención técnica en terreno'),
    ('Inspeccion de Cauces - Gestion de reclamos', 'Gestión de reclamos de cauces'),
    ('Oficina Tecnica - Distribucion', 'Revisión técnica de proyectos de distribución'),
    ('Oficina Tecnica - Cartografia', 'Revisión técnica de proyectos de cartografía'),
    ('Oficina Tecnica - Turnos de Riego', 'Turnos de riego'),
    ('Oficina de Distribucion', 'Gestión de distribución de agua'),
    ('Oficina de Obras', 'Gestión de obras'),
    ('Presidencia', 'Dirección general del organismo'),
    ('Gerencia Hídrica', 'Firma y resolución'),
    ('Gerencia Técnica', 'Firma y resolución'),
    ('Subdelegacion Rio Mendoza', NULL),
    ('Elevación y resolución', NULL),
    ('Expediente electrónico', 'GDEMZA-DGIRR')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO tipos_expediente (nombre) VALUES
    ('Solicitud de construccion de puente'),
    ('Solicitud de ocupacion de servidumbre'),
    ('Solicitud de cobro cuota sostenimiento'),
    ('Denuncia de daños por caida de arboles'),
    ('Denuncia problemas para recibir el servicio'),
    ('Denuncia daños por desbordes'),
    ('Denuncia infraccion'),
    ('Solicitud de erradicacion de arboles'),
    ('Solicitud de rebaje de arboles'),
    ('Eliminacion de oficio'),
    ('Cambio de toma'),
    ('Acta de infraccion'),
    ('Renuncia al derecho de riego'),
    ('Certificado de factiblidad'),
    ('Solicitud de permiso precario'),
    ('Solicitud de permiso para toma de agua'),
    ('Solicitud de extincion de servidumbre'),
    ('Solicitud de colocacion de carteles'),
    ('Solicitud de informe de interferencias'),
    ('Presupuesto administrativo'),
    ('Solicitud de cruce de cañerias'),
    ('Solicitud de informe tecnico'),
    ('Informes varios'),
    ('Tramites generales')
ON CONFLICT (nombre) DO NOTHING;

-- ============================================================================
-- Fin del script
-- ============================================================================
