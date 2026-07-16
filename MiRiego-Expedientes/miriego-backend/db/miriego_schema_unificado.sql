-- ============================================================================
-- MiRiego — Esquema Unificado de Base de Datos
-- PostgreSQL 14+
-- ASIC Primera Zona de Riego — Godoy Cruz, Mendoza
-- ============================================================================
-- Este archivo unifica los 7 scripts SQL anteriores en orden cronológico:
--   1. miriego_schema_reclamos.sql     (schema + reclamos + jerarquía)
--   2. miriego_schema_expedientes.sql  (expedientes + pases + notas)
--   3. fix_expedientes_schema.sql      (columnas faltantes en expedientes)
--   4. fix_pases_condicional.sql       (pases condicionales + trigger fix)
--   5. fix_triggers.sql                (search_path en triggers)
--   6. miriego_reclamos_v2.sql         (v2 reclamos + datos semilla)
--   7. reclamos_v3_cc_pp.sql           (ccpp separado en cc + pp)
--
-- Las columnas agregadas por migraciones ya están incluidas directamente
-- en las definiciones CREATE TABLE. Este script es idempotente: usa
-- IF NOT EXISTS/ON CONFLICT DO NOTHING donde corresponde.
--
-- Modo de uso (fresh start):
--   psql -U postgres -d miriego -f miriego_schema_unificado.sql
--
-- O sobre una DB existente (solo aplica lo que falta):
--   psql -U postgres -d miriego -f miriego_schema_unificado.sql
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS miriego;
SET search_path TO miriego, public;

-- ============================================================================
-- 1. TIPOS ENUM
-- ============================================================================

CREATE TYPE rol_usuario AS ENUM (
    'regante',
    'tomero',
    'inspector',
    'administrador',
    'asociacion',
    'vecino'
);

CREATE TYPE prioridad_reclamo AS ENUM (
    'baja',
    'media',
    'alta',
    'critica'
);

CREATE TYPE estado_reclamo AS ENUM (
    'nuevo',
    'recibido',
    'en_revision',
    'asignado',
    'en_proceso',
    'resuelto',
    'cerrado',
    'rechazado',
    'derivado',
    'derivado_expediente',
    'pendiente_informacion',
    'cancelado',
    'reabierto'
);

CREATE TYPE estado_expediente AS ENUM (
    'iniciado',
    'en_tramite',
    'pase_pendiente',
    'pendiente_firma',
    'observado',
    'resuelto',
    'archivado',
    'anulado'
);

CREATE TYPE estado_pase AS ENUM (
    'enviado',
    'recibido',
    'rechazado'
);

-- ============================================================================
-- 2. JERARQUÍA ORGANIZATIVA DEL RIEGO
--    cuenca -> asociacion -> inspeccion -> canal -> toma/nodo
-- ============================================================================

CREATE TABLE IF NOT EXISTS cuencas (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(150) NOT NULL,
    descripcion     TEXT,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS asociaciones (
    id              SERIAL PRIMARY KEY,
    cuenca_id       INTEGER NOT NULL REFERENCES cuencas(id),
    nombre          VARCHAR(150) NOT NULL,
    descripcion     TEXT,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS inspecciones (
    id              SERIAL PRIMARY KEY,
    asociacion_id   INTEGER NOT NULL REFERENCES asociaciones(id),
    nombre          VARCHAR(150) NOT NULL,
    inspector       VARCHAR(150),
    descripcion     TEXT,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS canales (
    id              SERIAL PRIMARY KEY,
    inspeccion_id   INTEGER NOT NULL REFERENCES inspecciones(id),
    codigo_canal    VARCHAR(20) NOT NULL,
    nombre          VARCHAR(150) NOT NULL,
    descripcion     TEXT,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (codigo_canal)
);

CREATE TABLE IF NOT EXISTS tomas (
    id              SERIAL PRIMARY KEY,
    canal_id        INTEGER NOT NULL REFERENCES canales(id),
    codigo_toma     VARCHAR(30) NOT NULL,
    nombre          VARCHAR(150),
    latitud         NUMERIC(10, 7),
    longitud        NUMERIC(10, 7),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (codigo_toma)
);

CREATE INDEX IF NOT EXISTS idx_tomas_canal ON tomas(canal_id);
CREATE INDEX IF NOT EXISTS idx_canales_inspeccion ON canales(inspeccion_id);
CREATE INDEX IF NOT EXISTS idx_inspecciones_asociacion ON inspecciones(asociacion_id);
CREATE INDEX IF NOT EXISTS idx_asociaciones_cuenca ON asociaciones(cuenca_id);

-- ============================================================================
-- 3. TOMEROS Y ASIGNACIÓN A TOMAS (muchos a muchos)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tomeros (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    apellido        VARCHAR(100) NOT NULL,
    dni             VARCHAR(15) UNIQUE,
    telefono        VARCHAR(30),
    email           VARCHAR(150),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tomero_tomas (
    id                  SERIAL PRIMARY KEY,
    tomero_id           INTEGER NOT NULL REFERENCES tomeros(id),
    toma_id             INTEGER NOT NULL REFERENCES tomas(id),
    fecha_asignacion    DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin           DATE,
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (tomero_id, toma_id, fecha_asignacion)
);

CREATE INDEX IF NOT EXISTS idx_tomero_tomas_toma ON tomero_tomas(toma_id) WHERE activo = TRUE;
CREATE INDEX IF NOT EXISTS idx_tomero_tomas_tomero ON tomero_tomas(tomero_id) WHERE activo = TRUE;

-- ============================================================================
-- 4. REGANTES Y CCPP
-- ============================================================================

CREATE TABLE IF NOT EXISTS regantes (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    apellido        VARCHAR(100) NOT NULL,
    dni_cuit        VARCHAR(20),
    telefono        VARCHAR(30),
    email           VARCHAR(150),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ccpp (
    id              SERIAL PRIMARY KEY,
    codigo_ccpp     VARCHAR(30) NOT NULL UNIQUE,
    regante_id      INTEGER NOT NULL REFERENCES regantes(id),
    toma_id         INTEGER NOT NULL REFERENCES tomas(id),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ccpp_regante ON ccpp(regante_id);
CREATE INDEX IF NOT EXISTS idx_ccpp_toma ON ccpp(toma_id);

-- ============================================================================
-- 5. USUARIOS DEL SISTEMA
-- ============================================================================

CREATE TABLE IF NOT EXISTS usuarios (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    apellido        VARCHAR(100) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    rol             rol_usuario NOT NULL,
    regante_id      INTEGER REFERENCES regantes(id),
    tomero_id       INTEGER REFERENCES tomeros(id),
    inspeccion_id   INTEGER REFERENCES inspecciones(id),
    asociacion_id   INTEGER REFERENCES asociaciones(id),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_usuarios_rol ON usuarios(rol);

-- ============================================================================
-- 6. CATEGORÍAS Y TIPOS DE RECLAMO
-- ============================================================================

CREATE TABLE IF NOT EXISTS categorias_reclamo (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS tipos_reclamo (
    id                  SERIAL PRIMARY KEY,
    categoria_id        INTEGER NOT NULL REFERENCES categorias_reclamo(id),
    nombre              VARCHAR(150) NOT NULL,
    descripcion         TEXT,
    prioridad_sugerida  prioridad_reclamo NOT NULL DEFAULT 'media',
    activo              BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_tipos_reclamo_categoria ON tipos_reclamo(categoria_id);

-- ============================================================================
-- 7. RECLAMOS
-- ============================================================================

CREATE TABLE IF NOT EXISTS reclamos (
    id                          SERIAL PRIMARY KEY,
    codigo_reclamo              VARCHAR(30) NOT NULL UNIQUE,

    usuario_id                  INTEGER NOT NULL REFERENCES usuarios(id),

    regante_id                  INTEGER REFERENCES regantes(id),
    ccpp_id                     INTEGER REFERENCES ccpp(id),
    toma_id                     INTEGER REFERENCES tomas(id),
    canal_id                    INTEGER REFERENCES canales(id),
    inspeccion_id               INTEGER REFERENCES inspecciones(id),
    asociacion_id               INTEGER REFERENCES asociaciones(id),
    cuenca_id                   INTEGER REFERENCES cuencas(id),
    tomero_id                   INTEGER REFERENCES tomeros(id),

    tipo_id                     INTEGER NOT NULL REFERENCES tipos_reclamo(id),
    categoria_id                INTEGER NOT NULL REFERENCES categorias_reclamo(id),
    prioridad                   prioridad_reclamo NOT NULL DEFAULT 'media',
    estado                      estado_reclamo NOT NULL DEFAULT 'nuevo',

    titulo                      VARCHAR(200) NOT NULL,
    descripcion                 TEXT NOT NULL,
    latitud                     NUMERIC(10, 7),
    longitud                    NUMERIC(10, 7),
    direccion_manual            TEXT,

    es_regante                  BOOLEAN NOT NULL DEFAULT TRUE,
    reclamante_nombre           VARCHAR(150),
    reclamante_apellido         VARCHAR(100),
    reclamante_dni              VARCHAR(20),
    reclamante_telefono         VARCHAR(30),
    reclamante_email            VARCHAR(150),
    reclamante_cc               VARCHAR(20),
    reclamante_pp               VARCHAR(20),

    turno_referencia            VARCHAR(50),

    fecha_creacion               TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_primera_respuesta      TIMESTAMPTZ,
    fecha_resolucion             TIMESTAMPTZ,
    fecha_cierre                 TIMESTAMPTZ,

    asignado_a                   INTEGER REFERENCES usuarios(id),
    expediente_id                INTEGER,

    CONSTRAINT chk_reclamo_tiene_ubicacion
        CHECK (
            ccpp_id IS NOT NULL
            OR toma_id IS NOT NULL
            OR (latitud IS NOT NULL AND longitud IS NOT NULL)
            OR direccion_manual IS NOT NULL
        ),
    CONSTRAINT chk_no_regante_sin_ccpp
        CHECK (es_regante = TRUE OR ccpp_id IS NULL)
);

CREATE INDEX IF NOT EXISTS idx_reclamos_estado ON reclamos(estado);
CREATE INDEX IF NOT EXISTS idx_reclamos_prioridad ON reclamos(prioridad);
CREATE INDEX IF NOT EXISTS idx_reclamos_regante ON reclamos(regante_id);
CREATE INDEX IF NOT EXISTS idx_reclamos_toma ON reclamos(toma_id);
CREATE INDEX IF NOT EXISTS idx_reclamos_canal ON reclamos(canal_id);
CREATE INDEX IF NOT EXISTS idx_reclamos_inspeccion ON reclamos(inspeccion_id);
CREATE INDEX IF NOT EXISTS idx_reclamos_tomero ON reclamos(tomero_id);
CREATE INDEX IF NOT EXISTS idx_reclamos_fecha_creacion ON reclamos(fecha_creacion);
CREATE INDEX IF NOT EXISTS idx_reclamos_es_regante ON reclamos(es_regante) WHERE es_regante = FALSE;

-- ============================================================================
-- 8. COMENTARIOS, ADJUNTOS, HISTORIAL (reclamos)
-- ============================================================================

CREATE TABLE IF NOT EXISTS reclamo_comentarios (
    id              SERIAL PRIMARY KEY,
    reclamo_id      INTEGER NOT NULL REFERENCES reclamos(id) ON DELETE CASCADE,
    usuario_id      INTEGER NOT NULL REFERENCES usuarios(id),
    rol_usuario     rol_usuario NOT NULL,
    comentario      TEXT NOT NULL,
    es_interno      BOOLEAN NOT NULL DEFAULT FALSE,
    fecha           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comentarios_reclamo ON reclamo_comentarios(reclamo_id);

CREATE TABLE IF NOT EXISTS reclamo_adjuntos (
    id              SERIAL PRIMARY KEY,
    reclamo_id      INTEGER NOT NULL REFERENCES reclamos(id) ON DELETE CASCADE,
    archivo_url     TEXT NOT NULL,
    tipo_archivo    VARCHAR(50),
    descripcion     VARCHAR(255),
    fecha           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_adjuntos_reclamo ON reclamo_adjuntos(reclamo_id);

CREATE TABLE IF NOT EXISTS reclamo_historial (
    id              SERIAL PRIMARY KEY,
    reclamo_id      INTEGER NOT NULL REFERENCES reclamos(id) ON DELETE CASCADE,
    usuario_id      INTEGER REFERENCES usuarios(id),
    accion          VARCHAR(100) NOT NULL,
    estado_anterior estado_reclamo,
    estado_nuevo    estado_reclamo,
    observacion     TEXT,
    fecha           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_historial_reclamo ON reclamo_historial(reclamo_id);

-- ============================================================================
-- 9. SECTORES (dependencias internas del organismo)
-- ============================================================================

CREATE TABLE IF NOT EXISTS sectores (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(150) NOT NULL UNIQUE,
    descripcion     TEXT,
    sector_padre_id INTEGER REFERENCES sectores(id),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================================
-- 10. TIPOS DE EXPEDIENTE
-- ============================================================================

CREATE TABLE IF NOT EXISTS tipos_expediente (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(150) NOT NULL UNIQUE,
    descripcion     TEXT,
    activo          BOOLEAN NOT NULL DEFAULT TRUE
);

-- ============================================================================
-- 11. EXPEDIENTES
-- ============================================================================

CREATE TABLE IF NOT EXISTS expedientes (
    id                      SERIAL PRIMARY KEY,
    numero_expediente       VARCHAR(40) NOT NULL UNIQUE,
    tipo_id                 INTEGER NOT NULL REFERENCES tipos_expediente(id),

    asunto                  VARCHAR(250) NOT NULL,
    descripcion             TEXT,

    iniciador_nombre        VARCHAR(150) NOT NULL,
    iniciador_dni_cuit      VARCHAR(20),
    iniciador_cc            VARCHAR(20),
    iniciador_pp            VARCHAR(20),
    regante_id              INTEGER,
    inspeccion_id           INTEGER,

    sector_actual_id        INTEGER NOT NULL REFERENCES sectores(id),
    estado                  estado_expediente NOT NULL DEFAULT 'iniciado',

    gde_numero              VARCHAR(60),
    infogov_numero          VARCHAR(60),
    expediente_acumulado_numero VARCHAR(40),

    fecha_inicio            TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_ultima_actualizacion TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_resolucion        TIMESTAMPTZ,
    fecha_archivo           TIMESTAMPTZ,
    fecha_vencimiento       TIMESTAMPTZ,

    creado_por              INTEGER
);

CREATE INDEX IF NOT EXISTS idx_expedientes_sector_actual ON expedientes(sector_actual_id);
CREATE INDEX IF NOT EXISTS idx_expedientes_estado ON expedientes(estado);
CREATE INDEX IF NOT EXISTS idx_expedientes_tipo ON expedientes(tipo_id);
CREATE INDEX IF NOT EXISTS idx_expedientes_fecha_inicio ON expedientes(fecha_inicio);

-- ============================================================================
-- 12. PASES (movimientos entre sectores)
-- ============================================================================

CREATE TABLE IF NOT EXISTS pases (
    id                  SERIAL PRIMARY KEY,
    expediente_id       INTEGER NOT NULL REFERENCES expedientes(id) ON DELETE CASCADE,
    sector_origen_id    INTEGER NOT NULL REFERENCES sectores(id),
    sector_destino_id   INTEGER NOT NULL REFERENCES sectores(id),
    usuario_id          INTEGER,
    motivo              VARCHAR(250),
    observaciones       TEXT,
    inspeccion_id       INTEGER,
    subsector_mesa_entradas VARCHAR(50),
    usuario_asignado_id INTEGER,
    estado              estado_pase NOT NULL DEFAULT 'enviado',
    fecha_envio         TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_recepcion     TIMESTAMPTZ,
    fecha_vencimiento   TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_pases_expediente ON pases(expediente_id);
CREATE INDEX IF NOT EXISTS idx_pases_sector_destino ON pases(sector_destino_id) WHERE estado = 'enviado';

-- ============================================================================
-- 13. NOTAS
-- ============================================================================

CREATE TABLE IF NOT EXISTS notas (
    id                  SERIAL PRIMARY KEY,
    expediente_id       INTEGER NOT NULL REFERENCES expedientes(id) ON DELETE CASCADE,
    sector_id           INTEGER NOT NULL REFERENCES sectores(id),
    usuario_id          INTEGER,
    contenido           TEXT NOT NULL,
    es_interna          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notas_expediente ON notas(expediente_id);

-- ============================================================================
-- 14. ADJUNTOS (expedientes)
-- ============================================================================

CREATE TABLE IF NOT EXISTS expediente_adjuntos (
    id              SERIAL PRIMARY KEY,
    expediente_id   INTEGER NOT NULL REFERENCES expedientes(id) ON DELETE CASCADE,
    archivo_url     TEXT NOT NULL,
    tipo_archivo    VARCHAR(50),
    descripcion     VARCHAR(255),
    fecha           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expediente_adjuntos_expediente ON expediente_adjuntos(expediente_id);

-- ============================================================================
-- 15. HISTORIAL (expedientes)
-- ============================================================================

CREATE TABLE IF NOT EXISTS expediente_historial (
    id                  SERIAL PRIMARY KEY,
    expediente_id       INTEGER NOT NULL REFERENCES expedientes(id) ON DELETE CASCADE,
    usuario_id          INTEGER,
    accion              VARCHAR(100) NOT NULL,
    estado_anterior     estado_expediente,
    estado_nuevo        estado_expediente,
    sector_anterior_id  INTEGER REFERENCES sectores(id),
    sector_nuevo_id     INTEGER REFERENCES sectores(id),
    observacion         TEXT,
    fecha               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expediente_historial_expediente ON expediente_historial(expediente_id);

-- ============================================================================
-- 16. TRIGGERS
-- ============================================================================

-- Trigger: auto-resolución de jerarquía + tomero al crear un reclamo
CREATE OR REPLACE FUNCTION fn_resolver_jerarquia_reclamo()
RETURNS TRIGGER AS $$
DECLARE
    v_toma_id       INTEGER;
    v_canal_id      INTEGER;
    v_inspeccion_id INTEGER;
    v_asociacion_id INTEGER;
    v_cuenca_id     INTEGER;
    v_tomero_id     INTEGER;
BEGIN
    IF NEW.ccpp_id IS NOT NULL THEN
        SELECT toma_id INTO v_toma_id FROM ccpp WHERE id = NEW.ccpp_id;
    ELSE
        v_toma_id := NEW.toma_id;
    END IF;

    IF v_toma_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT c.id, c.inspeccion_id
        INTO v_canal_id, v_inspeccion_id
        FROM tomas t
        JOIN canales c ON c.id = t.canal_id
        WHERE t.id = v_toma_id;

    SELECT i.asociacion_id INTO v_asociacion_id
        FROM inspecciones i WHERE i.id = v_inspeccion_id;

    SELECT a.cuenca_id INTO v_cuenca_id
        FROM asociaciones a WHERE a.id = v_asociacion_id;

    SELECT tt.tomero_id INTO v_tomero_id
        FROM tomero_tomas tt
        WHERE tt.toma_id = v_toma_id AND tt.activo = TRUE
        ORDER BY tt.fecha_asignacion DESC
        LIMIT 1;

    NEW.toma_id       := v_toma_id;
    NEW.canal_id      := v_canal_id;
    NEW.inspeccion_id := v_inspeccion_id;
    NEW.asociacion_id := v_asociacion_id;
    NEW.cuenca_id     := v_cuenca_id;
    NEW.tomero_id     := COALESCE(NEW.tomero_id, v_tomero_id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = miriego, public;

DROP TRIGGER IF EXISTS trg_resolver_jerarquia_reclamo ON reclamos;
CREATE TRIGGER trg_resolver_jerarquia_reclamo
    BEFORE INSERT ON reclamos
    FOR EACH ROW
    EXECUTE FUNCTION fn_resolver_jerarquia_reclamo();

-- Trigger: registrar historial automático en cambios de estado de reclamo
CREATE OR REPLACE FUNCTION fn_registrar_historial_estado()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO reclamo_historial (reclamo_id, usuario_id, accion, estado_anterior, estado_nuevo)
        VALUES (NEW.id, NEW.usuario_id, 'creacion', NULL, NEW.estado);
    ELSIF TG_OP = 'UPDATE' AND OLD.estado IS DISTINCT FROM NEW.estado THEN
        INSERT INTO reclamo_historial (reclamo_id, usuario_id, accion, estado_anterior, estado_nuevo)
        VALUES (NEW.id, NEW.asignado_a, 'cambio_estado', OLD.estado, NEW.estado);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = miriego, public;

DROP TRIGGER IF EXISTS trg_historial_reclamo ON reclamos;
CREATE TRIGGER trg_historial_reclamo
    AFTER INSERT OR UPDATE ON reclamos
    FOR EACH ROW
    EXECUTE FUNCTION fn_registrar_historial_estado();

-- Trigger: aplicar pase (actualizar sector_actual_id y estado del expediente)
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
$$ LANGUAGE plpgsql
SET search_path = miriego, public;

DROP TRIGGER IF EXISTS trg_aplicar_pase ON pases;
CREATE TRIGGER trg_aplicar_pase
    AFTER INSERT ON pases
    FOR EACH ROW
    EXECUTE FUNCTION fn_aplicar_pase();

-- ============================================================================
-- 17. DATOS SEMILLA
-- ============================================================================

-- Usuario por defecto (MVP sin auth)
INSERT INTO usuarios (nombre, apellido, email, rol)
VALUES ('Admin', 'Sistema', 'admin@miriego.local', 'administrador')
ON CONFLICT DO NOTHING;

-- Categorías de reclamo
INSERT INTO categorias_reclamo (nombre) VALUES
    ('turno'),
    ('infraestructura'),
    ('administrativo'),
    ('general')
ON CONFLICT DO NOTHING;

-- Tipos de reclamo
INSERT INTO tipos_reclamo (categoria_id, nombre, prioridad_sugerida) VALUES
    (2, 'Denuncia de daños por caída de árboles', 'alta'),
    (2, 'Denuncia daños por desbordes', 'alta'),
    (2, 'Denuncia construcción clandestina', 'alta'),
    (2, 'Denuncia filtración', 'media'),
    (4, 'Denuncia problemas para recibir el servicio', 'media'),
    (4, 'Denuncia derivación de agua', 'alta'),
    (4, 'Reclamos varios', 'media'),
    (3, 'Denuncia infracción', 'media')
ON CONFLICT DO NOTHING;

-- Cuenca base
INSERT INTO cuencas (nombre, descripcion) VALUES
    ('Cuenca Godoy Cruz', 'Cuenca hidrográfica de Godoy Cruz, Mendoza')
ON CONFLICT DO NOTHING;

-- Asociación base
INSERT INTO asociaciones (cuenca_id, nombre, descripcion)
SELECT id, 'ASIC Primera Zona de Riego', 'Asociación de Canalistas Primera Zona de Riego — Godoy Cruz, Mendoza'
FROM cuencas WHERE nombre = 'Cuenca Godoy Cruz'
ON CONFLICT DO NOTHING;

-- Inspecciones
DO $$
DECLARE
    v_asoc_id INTEGER;
BEGIN
    SELECT id INTO v_asoc_id FROM asociaciones WHERE nombre = 'ASIC Primera Zona de Riego';

    INSERT INTO inspecciones (asociacion_id, nombre, inspector) VALUES
        (v_asoc_id, 'Inspección Canal del Oeste', 'Nestor Ippolitti'),
        (v_asoc_id, 'Inspección Hijuela Civit', 'Mauricio Battochia'),
        (v_asoc_id, 'Inspección Luján Oeste Unificada', 'Alejandro Diez'),
        (v_asoc_id, 'Inspección Canal Compuertas', 'Juan Carlos De Blassis'),
        (v_asoc_id, 'Inspección Rama Jarillal', 'Gerardo Galeotti'),
        (v_asoc_id, 'Inspección Rama Tajamar', 'Emilio Pezzola'),
        (v_asoc_id, 'Inspección Luján Sur Unificada', 'Emilio Blanco'),
        (v_asoc_id, 'Asociación Primera Zona de riego', 'Alejandro Diez')
    ON CONFLICT DO NOTHING;
END $$;

-- Canales
DO $$
DECLARE
    v_insp_co        INTEGER;
    v_insp_hc        INTEGER;
    v_insp_lo        INTEGER;
    v_insp_cc        INTEGER;
    v_insp_rj        INTEGER;
    v_insp_rt        INTEGER;
    v_insp_ls        INTEGER;
    v_insp_apzr      INTEGER;
BEGIN
    SELECT id INTO v_insp_co   FROM inspecciones WHERE nombre = 'Inspección Canal del Oeste';
    SELECT id INTO v_insp_hc   FROM inspecciones WHERE nombre = 'Inspección Hijuela Civit';
    SELECT id INTO v_insp_lo   FROM inspecciones WHERE nombre = 'Inspección Luján Oeste Unificada';
    SELECT id INTO v_insp_cc   FROM inspecciones WHERE nombre = 'Inspección Canal Compuertas';
    SELECT id INTO v_insp_rj   FROM inspecciones WHERE nombre = 'Inspección Rama Jarillal';
    SELECT id INTO v_insp_rt   FROM inspecciones WHERE nombre = 'Inspección Rama Tajamar';
    SELECT id INTO v_insp_ls   FROM inspecciones WHERE nombre = 'Inspección Luján Sur Unificada';
    SELECT id INTO v_insp_apzr FROM inspecciones WHERE nombre = 'Asociación Primera Zona de riego';

    INSERT INTO canales (inspeccion_id, codigo_canal, nombre) VALUES
        (v_insp_co, '1038', 'Canal del Oeste'),
        (v_insp_hc, '1039', 'Hijuela Civit'),
        (v_insp_lo, '1010', 'Hijuela 2do Vistalba'),
        (v_insp_lo, '1016', 'Hijuela La Falda'),
        (v_insp_lo, '1012', 'Hijuela Chacras de coria'),
        (v_insp_lo, '1013', 'Ramo Pueyrredon'),
        (v_insp_lo, '1014', 'Ramo Godoy'),
        (v_insp_lo, '1015', 'Ramo doce'),
        (v_insp_lo, '1106', 'Canal 1ro Vistalba'),
        (v_insp_cc, '1104', 'Canal Compuertas'),
        (v_insp_cc, '1105', 'Hijuela Pincolini'),
        (v_insp_rj, '1037', 'Rama Jarillal'),
        (v_insp_rj, '1041', 'Hijuela Molina'),
        (v_insp_rj, '1042', 'Hijuela Gonzalez'),
        (v_insp_rj, '1043', 'Hijuela Alcaye'),
        (v_insp_rj, '1044', 'Hijuela Ferreyra'),
        (v_insp_rj, '1045', 'Hijuela El Rincon'),
        (v_insp_rj, '1046', 'Hijuela Chimbera'),
        (v_insp_rj, '1047', 'Hijuela Funes'),
        (v_insp_rj, '1048', 'Hijuela Zalazar'),
        (v_insp_rj, '1049', 'Hijuela Del Alto'),
        (v_insp_rj, '1050', 'Hijuela 1° Guevara'),
        (v_insp_rj, '1051', 'Hijuela 2° Guevara'),
        (v_insp_rj, '1052', 'Hijuela 3° Guevara'),
        (v_insp_rj, '1053', 'Hijuela 4° Guevara'),
        (v_insp_rj, '1054', 'Hijuela Allayme'),
        (v_insp_rt, '1070', 'Rama Tajamar'),
        (v_insp_rt, '1071', 'Hijuela Chimba'),
        (v_insp_rt, '1072', 'Ramo Manzano'),
        (v_insp_rt, '1073', 'Ramo Furlani'),
        (v_insp_rt, '1074', 'Hijuela Zapallar'),
        (v_insp_rt, '1075', 'Ramo Moyano'),
        (v_insp_rt, '1076', 'Ramo Plumerillo'),
        (v_insp_rt, '1077', 'Ramo Hoyos'),
        (v_insp_rt, '1078', 'Ramo Saez'),
        (v_insp_rt, '1079', 'Ramo Puebla'),
        (v_insp_rt, '1080', 'Ramo Torres'),
        (v_insp_rt, '1081', 'Ramo Cabrera'),
        (v_insp_rt, '1082', 'Ramo Bonfanti'),
        (v_insp_rt, '1083', 'Ramo Mascota'),
        (v_insp_rt, '1084', 'Ramo Cichitti'),
        (v_insp_rt, '1085', 'Toma Particular'),
        (v_insp_rt, '1086', 'Toma J. Monteavaro y otros'),
        (v_insp_rt, '1766', 'Vertientes Borbollon'),
        (v_insp_rt, '1912', 'Desague Alvarez Condarco'),
        (v_insp_ls, '1107', 'Canal Flores'),
        (v_insp_ls, '1108', 'Hijuela Quinteros'),
        (v_insp_ls, '1109', 'Hijuela Bella Vista'),
        (v_insp_ls, '1111', 'Hijuela Bella Vista'),
        (v_insp_ls, '1112', 'Canal Corvalan'),
        (v_insp_ls, '1113', 'Canal Santander'),
        (v_insp_ls, '1919', 'Concesión de desagues'),
        (v_insp_apzr, '1020', 'Asociación Primera Zona de riego')
    ON CONFLICT (codigo_canal) DO NOTHING;
END $$;

-- Sectores
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

-- Tipos de expediente
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
    ('Informes varios')
ON CONFLICT (nombre) DO NOTHING;

-- ============================================================================
-- Fin del script unificado
-- ============================================================================
