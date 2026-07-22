-- Migración: fix notificaciones
-- 1. Secuencia para codigo_notificacion CE-XXXX
-- 2. Valor por defecto para codigo_notificacion usando la secuencia
-- 3. Eliminar notificado_ccpp si existe (ya reemplazado por cc + pp)

SET search_path TO miriego, public;

-- Secuencia para generar códigos CE-0001, CE-0002, ...
CREATE SEQUENCE IF NOT EXISTS miriego.seq_codigo_notificacion START 1;

-- Backfill: numerar registros existentes que no tienen código
DO $$
DECLARE
    rec RECORD;
    seq_val INTEGER;
BEGIN
    FOR rec IN SELECT id FROM miriego.notificaciones ORDER BY id LOOP
        seq_val := nextval('miriego.seq_codigo_notificacion');
        UPDATE miriego.notificaciones
        SET codigo_notificacion = 'CE-' || LPAD(seq_val::text, 4, '0')
        WHERE id = rec.id AND (codigo_notificacion IS NULL OR codigo_notificacion = '');
    END LOOP;
END $$;

-- Valor por defecto: genera CE-XXXX usando la secuencia
ALTER TABLE miriego.notificaciones
    ALTER COLUMN codigo_notificacion SET DEFAULT 'CE-' || LPAD(nextval('miriego.seq_codigo_notificacion')::text, 4, '0');

-- Eliminar columna notificado_ccpp si existe (ya reemplazada por cc + pp)
ALTER TABLE miriego.notificaciones
    DROP COLUMN IF EXISTS notificado_ccpp;
