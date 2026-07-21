-- Migración: módulo de Notificaciones
-- Ejecutar: psql -U postgres -d miriego -f miriego-backend/db/notificaciones_schema.sql

-- Enums
DO $$ BEGIN
    CREATE TYPE miriego.notificado_tipo AS ENUM ('regante', 'tercero');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE miriego.estado_notificacion AS ENUM (
        'emitida', 'notificada', 'respondida', 'vencida', 'cumplida', 'cerrada'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Catálogo: tipos de notificación
CREATE TABLE IF NOT EXISTS miriego.tipos_notificaciones (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO miriego.tipos_notificaciones (nombre)
SELECT 'General'
WHERE NOT EXISTS (SELECT 1 FROM miriego.tipos_notificaciones);

-- Catálogo: medios de notificación
CREATE TABLE IF NOT EXISTS miriego.medios_notificacion (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO miriego.medios_notificacion (nombre)
SELECT v.nombre FROM (VALUES
    ('Personal'),
    ('Cédula'),
    ('Edicto'),
    ('Carta documento'),
    ('Email')
) AS v(nombre)
WHERE NOT EXISTS (SELECT 1 FROM miriego.medios_notificacion);

-- Tabla principal de notificaciones
CREATE TABLE IF NOT EXISTS miriego.notificaciones (
    id SERIAL PRIMARY KEY,
    codigo_notificacion VARCHAR(30) NOT NULL UNIQUE,

    tipo_notificacion_id INTEGER,
    medio_notificacion_id INTEGER,
    expediente_id INTEGER,

    notificado_tipo miriego.notificado_tipo NOT NULL DEFAULT 'tercero',
    notificado_ccpp VARCHAR(20),

    notificado_nombre VARCHAR(200),
    notificado_documento VARCHAR(30),
    notificado_domicilio TEXT,
    notificado_contacto VARCHAR(150),

    motivo VARCHAR(200) NOT NULL,
    descripcion TEXT NOT NULL,

    fecha_emision TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_notificacion TIMESTAMPTZ,
    fecha_vencimiento_respuesta TIMESTAMPTZ,

    estado miriego.estado_notificacion NOT NULL DEFAULT 'emitida',

    usuario_id INTEGER NOT NULL DEFAULT 1,
    observaciones TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION miriego.set_updated_at_notificaciones()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_updated_at_notificaciones ON miriego.notificaciones;
CREATE TRIGGER trg_updated_at_notificaciones
    BEFORE UPDATE ON miriego.notificaciones
    FOR EACH ROW
    EXECUTE FUNCTION miriego.set_updated_at_notificaciones();

-- Índices
CREATE INDEX IF NOT EXISTS idx_notificaciones_estado ON miriego.notificaciones(estado);
CREATE INDEX IF NOT EXISTS idx_notificaciones_fecha_emision ON miriego.notificaciones(fecha_emision);
CREATE INDEX IF NOT EXISTS idx_notificaciones_codigo ON miriego.notificaciones(codigo_notificacion);
