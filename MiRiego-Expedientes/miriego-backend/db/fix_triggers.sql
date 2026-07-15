SET search_path TO miriego, public;

-- Fix: both trigger functions now have SET search_path so they find
-- tables even when invoked from SQLAlchemy (which doesn't set search_path).

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
