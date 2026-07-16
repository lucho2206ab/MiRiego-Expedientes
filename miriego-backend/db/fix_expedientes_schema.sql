-- Migración: agregar columnas faltantes a la tabla expedientes
-- y corregir el valor del enum estado_expediente.
-- Ejecutar contra la base de datos miriego.

SET search_path TO miriego, public;

-- 1. Agregar columnas que el ORM espera pero el SQL original no definía
ALTER TABLE expedientes ADD COLUMN IF NOT EXISTS iniciador_cc  VARCHAR(20);
ALTER TABLE expedientes ADD COLUMN IF NOT EXISTS iniciador_pp  VARCHAR(20);
ALTER TABLE expedientes ADD COLUMN IF NOT EXISTS inspeccion_id  INTEGER;
ALTER TABLE expedientes ADD COLUMN IF NOT EXISTS fecha_vencimiento TIMESTAMPTZ;
ALTER TABLE expedientes ADD COLUMN IF NOT EXISTS expediente_acumulado_numero VARCHAR(40);

-- 2. Agregar columna faltante en pases
ALTER TABLE pases ADD COLUMN IF NOT EXISTS fecha_vencimiento TIMESTAMPTZ;

-- 3. Agregar 'pase_pendiente' al enum si falta (para esquemas viejos)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum e
        JOIN pg_type t ON e.enumtypid = t.oid
        WHERE t.typname = 'estado_expediente' AND e.enumlabel = 'pase_pendiente'
    ) THEN
        ALTER TYPE estado_expediente ADD VALUE IF NOT EXISTS 'pase_pendiente';
    END IF;
END $$;
