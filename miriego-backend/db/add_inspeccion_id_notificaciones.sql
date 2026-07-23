-- Agrega inspeccion_id a notificaciones para poder asignar
-- una inspección directamente (especialmente para terceros donde no hay CC).
-- La tabla inspecciones ya existe en el schema miriego.

ALTER TABLE miriego.notificaciones
ADD COLUMN IF NOT EXISTS inspeccion_id INTEGER;
