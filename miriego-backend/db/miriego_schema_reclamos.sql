-- ============================================================================
-- MiRiego — Arquitectura de Base de Datos
-- Módulo: Reclamos + Tablas jerárquicas de soporte
-- Motor: PostgreSQL 14+
-- ASIC Primera Zona de Riego — Godoy Cruz, Mendoza
-- ============================================================================
-- Notas de diseño:
-- 1. Se crea un schema dedicado "miriego" para no mezclar con otras apps
--    que puedan compartir la misma instancia de Postgres.
-- 2. Las tablas jerárquicas (cuenca -> asociacion -> inspeccion -> canal ->
--    toma) se modelan primero porque reclamos depende de ellas via FK.
-- 3. CCPP es la clave de identidad del regante: un regante puede tener
--    varios CCPP (uno por toma/canal en el que riega).
-- 4. Se agrega un trigger que auto-resuelve canal/inspeccion/asociacion/
--    cuenca y tomero_id a partir de ccpp_id o toma_id al crear un reclamo,
--    tal como se definió en el diseño de MiRiego.
-- 5. Nombres de tablas/columnas en español para mantener consistencia con
--    la terminología del organismo (CCPP, tomero, toma, etc.)
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
    'vecino'          -- persona no regante (sin CCPP) que puede reclamar,
                      -- ej: anegación de propiedad, daño en vía pública, etc.
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

-- ============================================================================
-- 2. JERARQUÍA ORGANIZATIVA DEL RIEGO
--    cuenca -> asociacion -> inspeccion -> canal -> toma/nodo
-- ============================================================================

CREATE TABLE cuencas (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(150) NOT NULL,
    descripcion     TEXT,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE asociaciones (
    id              SERIAL PRIMARY KEY,
    cuenca_id       INTEGER NOT NULL REFERENCES cuencas(id),
    nombre          VARCHAR(150) NOT NULL,
    descripcion     TEXT,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE inspecciones (
    id              SERIAL PRIMARY KEY,
    asociacion_id   INTEGER NOT NULL REFERENCES asociaciones(id),
    nombre          VARCHAR(150) NOT NULL,
    inspector       VARCHAR(150),
    descripcion     TEXT,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE canales (
    id              SERIAL PRIMARY KEY,
    inspeccion_id   INTEGER NOT NULL REFERENCES inspecciones(id),
    codigo_canal    VARCHAR(20) NOT NULL,  -- CC
    nombre          VARCHAR(150) NOT NULL,
    descripcion     TEXT,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (codigo_canal)
);

CREATE TABLE tomas (
    id              SERIAL PRIMARY KEY,
    canal_id        INTEGER NOT NULL REFERENCES canales(id),
    codigo_toma     VARCHAR(30) NOT NULL,  -- toma/nodo: unidad mínima de gestión
    nombre          VARCHAR(150),
    latitud         NUMERIC(10, 7),
    longitud        NUMERIC(10, 7),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (codigo_toma)
);

CREATE INDEX idx_tomas_canal ON tomas(canal_id);
CREATE INDEX idx_canales_inspeccion ON canales(inspeccion_id);
CREATE INDEX idx_inspecciones_asociacion ON inspecciones(asociacion_id);
CREATE INDEX idx_asociaciones_cuenca ON asociaciones(cuenca_id);

-- ============================================================================
-- 3. TOMEROS Y ASIGNACIÓN A TOMAS (muchos a muchos)
-- ============================================================================

CREATE TABLE tomeros (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    apellido        VARCHAR(100) NOT NULL,
    dni             VARCHAR(15) UNIQUE,
    telefono        VARCHAR(30),
    email           VARCHAR(150),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE tomero_tomas (
    id                  SERIAL PRIMARY KEY,
    tomero_id           INTEGER NOT NULL REFERENCES tomeros(id),
    toma_id             INTEGER NOT NULL REFERENCES tomas(id),
    fecha_asignacion    DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin           DATE,  -- NULL = asignación vigente
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (tomero_id, toma_id, fecha_asignacion)
);

CREATE INDEX idx_tomero_tomas_toma ON tomero_tomas(toma_id) WHERE activo = TRUE;
CREATE INDEX idx_tomero_tomas_tomero ON tomero_tomas(tomero_id) WHERE activo = TRUE;

-- ============================================================================
-- 4. REGANTES Y CCPP
--    CCPP (Código de Cauce + Padrón Parcial) es la clave de identidad del
--    regante frente a Irrigación. Un regante puede tener varios CCPP.
-- ============================================================================

CREATE TABLE regantes (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    apellido        VARCHAR(100) NOT NULL,
    dni_cuit        VARCHAR(20),
    telefono        VARCHAR(30),
    email           VARCHAR(150),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ccpp (
    id              SERIAL PRIMARY KEY,
    codigo_ccpp     VARCHAR(30) NOT NULL UNIQUE,  -- CC + PP
    regante_id      INTEGER NOT NULL REFERENCES regantes(id),
    toma_id         INTEGER NOT NULL REFERENCES tomas(id),
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_ccpp_regante ON ccpp(regante_id);
CREATE INDEX idx_ccpp_toma ON ccpp(toma_id);

-- ============================================================================
-- 5. USUARIOS DEL SISTEMA
--    Un usuario del sistema puede corresponder a un regante, un tomero,
--    o ser un usuario "puro" (inspector/administrador/asociación) sin
--    referencia externa.
-- ============================================================================

CREATE TABLE usuarios (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    apellido        VARCHAR(100) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    rol             rol_usuario NOT NULL,
    regante_id      INTEGER REFERENCES regantes(id),
    tomero_id       INTEGER REFERENCES tomeros(id),
    inspeccion_id   INTEGER REFERENCES inspecciones(id),  -- si rol = inspector
    asociacion_id   INTEGER REFERENCES asociaciones(id),  -- si rol = asociacion
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_usuarios_rol ON usuarios(rol);

-- ============================================================================
-- 6. CATEGORÍAS Y TIPOS DE RECLAMO
-- ============================================================================

CREATE TABLE categorias_reclamo (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL UNIQUE  -- turno / infraestructura / administrativo / general
);

CREATE TABLE tipos_reclamo (
    id                  SERIAL PRIMARY KEY,
    categoria_id        INTEGER NOT NULL REFERENCES categorias_reclamo(id),
    nombre              VARCHAR(150) NOT NULL,
    descripcion          TEXT,
    prioridad_sugerida  prioridad_reclamo NOT NULL DEFAULT 'media',
    activo              BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_tipos_reclamo_categoria ON tipos_reclamo(categoria_id);

-- ============================================================================
-- 7. RECLAMOS
-- ============================================================================

CREATE TABLE reclamos (
    id                          SERIAL PRIMARY KEY,
    codigo_reclamo              VARCHAR(30) NOT NULL UNIQUE,  -- ej: RCL-2026-000123

    -- Quién lo crea
    usuario_id                  INTEGER NOT NULL REFERENCES usuarios(id),

    -- Identidad del regante / ubicación en la jerarquía de riego
    regante_id                  INTEGER REFERENCES regantes(id),
    ccpp_id                     INTEGER REFERENCES ccpp(id),
    toma_id                     INTEGER REFERENCES tomas(id),
    canal_id                    INTEGER REFERENCES canales(id),
    inspeccion_id               INTEGER REFERENCES inspecciones(id),
    asociacion_id               INTEGER REFERENCES asociaciones(id),
    cuenca_id                   INTEGER REFERENCES cuencas(id),
    tomero_id                   INTEGER REFERENCES tomeros(id),

    -- Clasificación
    tipo_id                     INTEGER NOT NULL REFERENCES tipos_reclamo(id),
    categoria_id                INTEGER NOT NULL REFERENCES categorias_reclamo(id),
    prioridad                   prioridad_reclamo NOT NULL DEFAULT 'media',
    estado                      estado_reclamo NOT NULL DEFAULT 'nuevo',

    -- Contenido
    titulo                      VARCHAR(200) NOT NULL,
    descripcion                 TEXT NOT NULL,
    latitud                     NUMERIC(10, 7),
    longitud                    NUMERIC(10, 7),
    direccion_manual            TEXT,  -- dirección escrita a mano, para reclamantes
                                        -- que no tienen CCPP/toma asociada (vecinos)

    -- Datos del reclamante cuando NO es un regante con CCPP (ej: vecino
    -- con anegación). Permite registrar el reclamo aunque la persona no
    -- tenga cuenta previa vinculada a un CCPP.
    es_regante                  BOOLEAN NOT NULL DEFAULT TRUE,
    reclamante_nombre           VARCHAR(150),  -- nombre del reclamante (regante o vecino)
    reclamante_apellido         VARCHAR(100),  -- apellido del reclamante
    reclamante_dni              VARCHAR(20),
    reclamante_telefono         VARCHAR(30),
    reclamante_email            VARCHAR(150),  -- email de contacto (obligatorio)
    reclamante_cc               VARCHAR(20),   -- Código de Cauce (solo regante)
    reclamante_pp               VARCHAR(20),   -- Padrón Parcial (solo regante)

    -- Turno relacionado (si aplica) — referencia libre por ahora,
    -- se vincula a la tabla de turnos cuando exista ese módulo.
    turno_referencia            VARCHAR(50),

    -- Fechas de seguimiento
    fecha_creacion               TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_primera_respuesta      TIMESTAMPTZ,
    fecha_resolucion             TIMESTAMPTZ,
    fecha_cierre                 TIMESTAMPTZ,

    -- Asignación
    asignado_a                   INTEGER REFERENCES usuarios(id),
    expediente_id                INTEGER,  -- FK lógica al módulo de expedientes

    -- Debe existir AL MENOS una forma de ubicar el reclamo:
    -- CCPP, toma, coordenadas GPS, o una dirección manual.
    -- Esto cubre tanto al regante (que sí tiene CCPP/toma) como al
    -- vecino no regante (que puede no saber ninguno de los dos).
    CONSTRAINT chk_reclamo_tiene_ubicacion
        CHECK (
            ccpp_id IS NOT NULL
            OR toma_id IS NOT NULL
            OR (latitud IS NOT NULL AND longitud IS NOT NULL)
            OR direccion_manual IS NOT NULL
        ),

    -- Si no es regante, no debería tener CCPP asociado
    CONSTRAINT chk_no_regante_sin_ccpp
        CHECK (es_regante = TRUE OR ccpp_id IS NULL)
);

CREATE INDEX idx_reclamos_estado ON reclamos(estado);
CREATE INDEX idx_reclamos_prioridad ON reclamos(prioridad);
CREATE INDEX idx_reclamos_regante ON reclamos(regante_id);
CREATE INDEX idx_reclamos_toma ON reclamos(toma_id);
CREATE INDEX idx_reclamos_canal ON reclamos(canal_id);
CREATE INDEX idx_reclamos_inspeccion ON reclamos(inspeccion_id);
CREATE INDEX idx_reclamos_tomero ON reclamos(tomero_id);
CREATE INDEX idx_reclamos_fecha_creacion ON reclamos(fecha_creacion);
CREATE INDEX idx_reclamos_es_regante ON reclamos(es_regante) WHERE es_regante = FALSE;

-- ============================================================================
-- 8. COMENTARIOS, ADJUNTOS, HISTORIAL
-- ============================================================================

CREATE TABLE reclamo_comentarios (
    id              SERIAL PRIMARY KEY,
    reclamo_id      INTEGER NOT NULL REFERENCES reclamos(id) ON DELETE CASCADE,
    usuario_id      INTEGER NOT NULL REFERENCES usuarios(id),
    rol_usuario     rol_usuario NOT NULL,
    comentario      TEXT NOT NULL,
    es_interno      BOOLEAN NOT NULL DEFAULT FALSE,  -- TRUE = no visible para el regante
    fecha           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_comentarios_reclamo ON reclamo_comentarios(reclamo_id);

CREATE TABLE reclamo_adjuntos (
    id              SERIAL PRIMARY KEY,
    reclamo_id      INTEGER NOT NULL REFERENCES reclamos(id) ON DELETE CASCADE,
    archivo_url     TEXT NOT NULL,
    tipo_archivo    VARCHAR(50),  -- foto / video / audio / documento
    descripcion     VARCHAR(255),
    fecha           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_adjuntos_reclamo ON reclamo_adjuntos(reclamo_id);

CREATE TABLE reclamo_historial (
    id              SERIAL PRIMARY KEY,
    reclamo_id      INTEGER NOT NULL REFERENCES reclamos(id) ON DELETE CASCADE,
    usuario_id      INTEGER REFERENCES usuarios(id),
    accion          VARCHAR(100) NOT NULL,   -- ej: "cambio_estado", "asignacion", "comentario"
    estado_anterior estado_reclamo,
    estado_nuevo    estado_reclamo,
    observacion     TEXT,
    fecha           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_historial_reclamo ON reclamo_historial(reclamo_id);

-- ============================================================================
-- 9. TRIGGER: auto-resolución de jerarquía + tomero al crear un reclamo
--    A partir de ccpp_id (preferido) o toma_id, completa toma, canal,
--    inspeccion, asociacion, cuenca y asigna tomero_id desde tomero_tomas.
-- ============================================================================

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
    -- 1. Determinar toma_id: si vino ccpp_id, se resuelve la toma desde ahí.
    IF NEW.ccpp_id IS NOT NULL THEN
        SELECT toma_id INTO v_toma_id FROM ccpp WHERE id = NEW.ccpp_id;
    ELSE
        v_toma_id := NEW.toma_id;
    END IF;

    -- Caso vecino / reclamo sin CCPP ni toma conocida (ej: anegación de
    -- propiedad de alguien que no es regante): no hay nada que resolver
    -- automáticamente. El reclamo queda con jerarquía en NULL y un
    -- inspector la completa manualmente (UPDATE) cuando triangula la
    -- ubicación real a partir de las coordenadas o la dirección manual.
    IF v_toma_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- 2. Resolver canal -> inspeccion -> asociacion -> cuenca
    SELECT c.id, c.inspeccion_id
        INTO v_canal_id, v_inspeccion_id
        FROM tomas t
        JOIN canales c ON c.id = t.canal_id
        WHERE t.id = v_toma_id;

    SELECT i.asociacion_id INTO v_asociacion_id
        FROM inspecciones i WHERE i.id = v_inspeccion_id;

    SELECT a.cuenca_id INTO v_cuenca_id
        FROM asociaciones a WHERE a.id = v_asociacion_id;

    -- 3. Resolver tomero activo asignado a la toma (si hay varios, el más reciente)
    SELECT tt.tomero_id INTO v_tomero_id
        FROM tomero_tomas tt
        WHERE tt.toma_id = v_toma_id AND tt.activo = TRUE
        ORDER BY tt.fecha_asignacion DESC
        LIMIT 1;

    -- 4. Completar los campos en el reclamo
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

CREATE TRIGGER trg_resolver_jerarquia_reclamo
    BEFORE INSERT ON reclamos
    FOR EACH ROW
    EXECUTE FUNCTION fn_resolver_jerarquia_reclamo();

-- ============================================================================
-- 10. TRIGGER: registrar automáticamente el historial en cada cambio de estado
-- ============================================================================

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

CREATE TRIGGER trg_historial_reclamo
    AFTER INSERT OR UPDATE ON reclamos
    FOR EACH ROW
    EXECUTE FUNCTION fn_registrar_historial_estado();

-- ============================================================================
-- 11. DATOS SEMILLA MÍNIMOS (catálogos base) — ajustar con datos reales
-- ============================================================================

-- Usuario por defecto (MVP sin auth — usuario_id = 1 hardcodeado)
INSERT INTO usuarios (nombre, apellido, email, rol)
VALUES ('Admin', 'Sistema', 'admin@miriego.local', 'administrador')
ON CONFLICT DO NOTHING;

INSERT INTO categorias_reclamo (nombre) VALUES
    ('turno'),
    ('infraestructura'),
    ('administrativo'),
    ('general');

-- Tipos de reclamo — se vinculan a categorías existentes.
-- Para agregar nuevos tipos, solo hacer un INSERT sin tocar código.
INSERT INTO tipos_reclamo (categoria_id, nombre, prioridad_sugerida) VALUES
    -- infraestructura (2)
    (2, 'Denuncia de daños por caída de árboles', 'alta'),
    (2, 'Denuncia daños por desbordes', 'alta'),
    (2, 'Denuncia construcción clandestina', 'alta'),
    (2, 'Denuncia filtración', 'media'),
    -- general (4)
    (4, 'Denuncia problemas para recibir el servicio', 'media'),
    (4, 'Denuncia derivación de agua', 'alta'),
    (4, 'Reclamos varios', 'media'),
    -- administrativo (3)
    (3, 'Denuncia infracción', 'media');

-- ============================================================================
-- Fin del script
-- ============================================================================
