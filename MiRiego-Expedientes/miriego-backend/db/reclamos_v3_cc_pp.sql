SET search_path TO miriego, public;

-- ============================================================================
-- TAREA 1: Separar ccpp en cc + pp
-- La tabla reclamos tiene 1 registro (el que se creó en la prueba anterior).
-- La columna reclamante_ccpp_codigo estaba vacía (NULL) en ese registro.
-- No hay datos que migrar: se puede hacer DROP + ADD directamente.
-- ============================================================================

ALTER TABLE reclamos
    DROP COLUMN IF EXISTS reclamante_ccpp_codigo;

ALTER TABLE reclamos
    ADD COLUMN reclamante_cc VARCHAR(20),
    ADD COLUMN reclamante_pp VARCHAR(20);
