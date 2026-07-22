-- Migración: notificaciones — separar ccpp en cc + pp, trigger CE-XXXX
-- Ejecutar DESPUÉS de notificaciones_schema.sql
-- psql -U postgres -d miriego -f miriego-backend/db/fix_notificaciones_cc.sql

-- 1. Separar notificado_ccpp en cc + pp
ALTER TABLE miriego.notificaciones
    DROP COLUMN IF EXISTS notificado_ccpp;

ALTER TABLE miriego.notificaciones
    ADD COLUMN cc VARCHAR(20),
    ADD COLUMN pp VARCHAR(20);

-- 2. Secuencia para código notificación CE-XXXX
CREATE SEQUENCE IF NOT EXISTS miriego.seq_notificacion_codigo
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    NO CYCLE;

-- 3. Trigger: genera código CE-XXXX automáticamente al insertar
CREATE OR REPLACE FUNCTION miriego.fn_generar_codigo_notificacion()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.codigo_notificacion IS NULL OR NEW.codigo_notificacion = '' THEN
        NEW.codigo_notificacion := 'CE-' || lpad(nextval('miriego.seq_notificacion_codigo')::TEXT, 4, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_codigo_notificacion ON miriego.notificaciones;
CREATE TRIGGER trg_codigo_notificacion
    BEFORE INSERT ON miriego.notificaciones
    FOR EACH ROW
    EXECUTE FUNCTION miriego.fn_generar_codigo_notificacion();
