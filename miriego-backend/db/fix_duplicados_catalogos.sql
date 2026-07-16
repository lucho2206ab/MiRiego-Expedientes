-- ============================================================================
-- fix_duplicados_catalogos.sql
-- Limpia duplicados en tipos_reclamo e inspecciones, agrega UNIQUE constraints
-- para que no vuelva a pasar. Conserva siempre el registro de menor id.
-- ============================================================================

-- 1. tipos_reclamo: eliminar duplicados (conservar id menor)
DELETE FROM miriego.tipos_reclamo
WHERE id NOT IN (
    SELECT MIN(id)
    FROM miriego.tipos_reclamo
    GROUP BY nombre
);

-- 2. inspecciones: eliminar duplicados (conservar id menor)
DELETE FROM miriego.inspecciones
WHERE id NOT IN (
    SELECT MIN(id)
    FROM miriego.inspecciones
    GROUP BY nombre
);

-- 3. UNIQUE constraints para prevenir futuros duplicados
ALTER TABLE miriego.tipos_reclamo
    ADD CONSTRAINT uq_tipos_reclamo_nombre UNIQUE (nombre);

ALTER TABLE miriego.inspecciones
    ADD CONSTRAINT uq_inspecciones_nombre UNIQUE (nombre);

-- 4. Resetear secuencias para que los IDs continúen coherentemente
SELECT setval('miriego.tipos_reclamo_id_seq', (SELECT MAX(id) FROM miriego.tipos_reclamo));
SELECT setval('miriego.inspecciones_id_seq', (SELECT MAX(id) FROM miriego.inspecciones));
