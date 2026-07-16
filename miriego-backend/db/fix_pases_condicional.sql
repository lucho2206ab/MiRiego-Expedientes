-- Migracion: agregar columnas condicionales a la tabla pases
-- para soportar derivaciones a "Inspeccion de Cauces" (inspeccion_id)
-- y "Mesa de Entradas" (subsector_mesa_entradas + usuario_asignado_id).
-- Tambien agrega inspeccion_id a expedientes para asignacion a inspeccion.
-- Ejecutar contra la base de datos miriego.

SET search_path TO miriego, public;

-- 0. Columna en expedientes para asignar a una inspeccion
ALTER TABLE expedientes ADD COLUMN IF NOT EXISTS inspeccion_id INTEGER;

-- 1. Columna para guardar la inspeccion seleccionada al derivar a "Inspeccion de Cauces"
ALTER TABLE pases ADD COLUMN IF NOT EXISTS inspeccion_id INTEGER;

-- 2. Columna para guardar el subsector seleccionado al derivar a "Mesa de Entradas"
-- Valores permitidos: 'Casilla de Vencimiento', 'Notificador', 'Reserva',
-- 'Archivo Mesa de Entradas', 'Archivo Deposito'
ALTER TABLE pases ADD COLUMN IF NOT EXISTS subsector_mesa_entradas VARCHAR(50);

-- 3. Columna para asignar un usuario responsable a un pase de Mesa de Entradas
-- FK logica no estricta (sin constraint), para uso futuro
ALTER TABLE pases ADD COLUMN IF NOT EXISTS usuario_asignado_id INTEGER;

-- 4. Fix: fn_aplicar_pase() — search_path + estado archivado para archivo
--    Si el subsector es "Archivo Mesa de Entradas" o "Archivo Deposito",
--    el estado pasa a 'archivado' y se registra fecha_archivo.
--    Caso contrario, se mantiene 'en_tramite' como antes.

CREATE OR REPLACE FUNCTION miriego.fn_aplicar_pase()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.subsector_mesa_entradas IN ('Archivo Mesa de Entradas', 'Archivo Deposito') THEN
        UPDATE miriego.expedientes
            SET sector_actual_id = NEW.sector_destino_id,
                estado = 'archivado',
                fecha_archivo = now(),
                fecha_ultima_actualizacion = now()
            WHERE id = NEW.expediente_id;

        INSERT INTO miriego.expediente_historial (
            expediente_id, usuario_id, accion,
            estado_anterior, estado_nuevo,
            sector_anterior_id, sector_nuevo_id, observacion
        ) VALUES (
            NEW.expediente_id, NEW.usuario_id, 'pase',
            NULL, 'archivado',
            NEW.sector_origen_id, NEW.sector_destino_id, NEW.motivo
        );
    ELSE
        UPDATE miriego.expedientes
            SET sector_actual_id = NEW.sector_destino_id,
                estado = 'en_tramite',
                fecha_ultima_actualizacion = now()
            WHERE id = NEW.expediente_id;

        INSERT INTO miriego.expediente_historial (
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
