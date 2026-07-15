-- ============================================================================
-- MiRiego — Migración v2 del módulo de Reclamos
-- Ejecutar una vez: psql -U postgres -d miriego -f miriego_reclamos_v2.sql
-- ============================================================================

SET search_path TO miriego, public;

-- ============================================================================
-- 0. Usuario por defecto (MVP sin auth — usuario_id = 1 hardcodeado)
-- ============================================================================

INSERT INTO usuarios (nombre, apellido, email, rol)
VALUES ('Admin', 'Sistema', 'admin@miriego.local', 'administrador')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 1. TAREA 1: Insertar tipos_reclamo (la tabla estaba vacía)
-- ============================================================================

INSERT INTO tipos_reclamo (categoria_id, nombre, prioridad_sugerida) VALUES
    -- infraestructura (categoria_id = 2)
    (2, 'Denuncia de daños por caída de árboles', 'alta'),
    (2, 'Denuncia daños por desbordes', 'alta'),
    (2, 'Denuncia construcción clandestina', 'alta'),
    (2, 'Denuncia filtración', 'media'),
    -- general (categoria_id = 4)
    (4, 'Denuncia problemas para recibir el servicio', 'media'),
    (4, 'Denuncia derivación de agua', 'alta'),
    (4, 'Reclamos varios', 'media'),
    -- administrativo (categoria_id = 3)
    (3, 'Denuncia infracción', 'media');

-- ============================================================================
-- 2. TAREA 2/3: Agregar columnas faltantes a reclamos
--    - reclamante_apellido: para regante y vecino
--    - reclamante_email: para regante y vecino (obligatorio en ambos)
--    - reclamante_ccpp_codigo: código CCPP como texto (solo regante)
-- ============================================================================

ALTER TABLE reclamos
    ADD COLUMN IF NOT EXISTS reclamante_apellido VARCHAR(100),
    ADD COLUMN IF NOT EXISTS reclamante_email VARCHAR(150),
    ADD COLUMN IF NOT EXISTS reclamante_ccpp_codigo VARCHAR(30);

-- ============================================================================
-- 3. TAREA 4: Jerarquía de riego — cuenca, asociación, inspecciones, canales
-- ============================================================================

-- Cuenca base (una sola para toda la zona de riego)
INSERT INTO cuencas (nombre, descripcion) VALUES
    ('Cuenca Godoy Cruz', 'Cuenca hidrográfica de Godoy Cruz, Mendoza')
ON CONFLICT DO NOTHING;

-- Asociación base
INSERT INTO asociaciones (cuenca_id, nombre, descripcion)
SELECT id, 'ASIC Primera Zona de Riego', 'Asociación de Canalistas Primera Zona de Riego — Godoy Cruz, Mendoza'
FROM cuencas WHERE nombre = 'Cuenca Godoy Cruz'
ON CONFLICT DO NOTHING;

-- Agregar columna inspector a inspecciones (el schema original no la tenía)
ALTER TABLE inspecciones
    ADD COLUMN IF NOT EXISTS inspector VARCHAR(150);

-- Inspecciones
DO $$
DECLARE
    v_asoc_id INTEGER;
BEGIN
    SELECT id INTO v_asoc_id FROM asociaciones WHERE nombre = 'ASIC Primera Zona de Riego';

    INSERT INTO inspecciones (asociacion_id, nombre, inspector) VALUES
        (v_asoc_id, 'Inspección Canal del Oeste', 'Nestor Ippolitti'),
        (v_asoc_id, 'Inspección Hijuela Civit', 'Mauricio Battochia'),
        (v_asoc_id, 'Inspección Luján Oeste Unificada', 'Alejandro Diez'),
        (v_asoc_id, 'Inspección Canal Compuertas', 'Juan Carlos De Blassis'),
        (v_asoc_id, 'Inspección Rama Jarillal', 'Gerardo Galeotti'),
        (v_asoc_id, 'Inspección Rama Tajamar', 'Emilio Pezzola'),
        (v_asoc_id, 'Inspección Luján Sur Unificada', 'Emilio Blanco'),
        (v_asoc_id, 'Asociación Primera Zona de riego', 'Alejandro Diez')
    ON CONFLICT DO NOTHING;
END $$;

-- Canales — agrupados por inspección
DO $$
DECLARE
    v_insp_co        INTEGER;
    v_insp_hc        INTEGER;
    v_insp_lo        INTEGER;
    v_insp_cc        INTEGER;
    v_insp_rj        INTEGER;
    v_insp_rt        INTEGER;
    v_insp_ls        INTEGER;
    v_insp_apzr      INTEGER;
BEGIN
    SELECT id INTO v_insp_co   FROM inspecciones WHERE nombre = 'Inspección Canal del Oeste';
    SELECT id INTO v_insp_hc   FROM inspecciones WHERE nombre = 'Inspección Hijuela Civit';
    SELECT id INTO v_insp_lo   FROM inspecciones WHERE nombre = 'Inspección Luján Oeste Unificada';
    SELECT id INTO v_insp_cc   FROM inspecciones WHERE nombre = 'Inspección Canal Compuertas';
    SELECT id INTO v_insp_rj   FROM inspecciones WHERE nombre = 'Inspección Rama Jarillal';
    SELECT id INTO v_insp_rt   FROM inspecciones WHERE nombre = 'Inspección Rama Tajamar';
    SELECT id INTO v_insp_ls   FROM inspecciones WHERE nombre = 'Inspección Luján Sur Unificada';
    SELECT id INTO v_insp_apzr FROM inspecciones WHERE nombre = 'Asociación Primera Zona de riego';

    INSERT INTO canales (inspeccion_id, codigo_canal, nombre) VALUES
        -- Canal del Oeste
        (v_insp_co, '1038', 'Canal del Oeste'),
        -- Hijuela Civit
        (v_insp_hc, '1039', 'Hijuela Civit'),
        -- Luján Oeste Unificada
        (v_insp_lo, '1010', 'Hijuela 2do Vistalba'),
        (v_insp_lo, '1016', 'Hijuela La Falda'),
        (v_insp_lo, '1012', 'Hijuela Chacras de coria'),
        (v_insp_lo, '1013', 'Ramo Pueyrredon'),
        (v_insp_lo, '1014', 'Ramo Godoy'),
        (v_insp_lo, '1015', 'Ramo doce'),
        (v_insp_lo, '1106', 'Canal 1ro Vistalba'),
        -- Canal Compuertas
        (v_insp_cc, '1104', 'Canal Compuertas'),
        (v_insp_cc, '1105', 'Hijuela Pincolini'),
        -- Rama Jarillal
        (v_insp_rj, '1037', 'Rama Jarillal'),
        (v_insp_rj, '1041', 'Hijuela Molina'),
        (v_insp_rj, '1042', 'Hijuela Gonzalez'),
        (v_insp_rj, '1043', 'Hijuela Alcaye'),
        (v_insp_rj, '1044', 'Hijuela Ferreyra'),
        (v_insp_rj, '1045', 'Hijuela El Rincon'),
        (v_insp_rj, '1046', 'Hijuela Chimbera'),
        (v_insp_rj, '1047', 'Hijuela Funes'),
        (v_insp_rj, '1048', 'Hijuela Zalazar'),
        (v_insp_rj, '1049', 'Hijuela Del Alto'),
        (v_insp_rj, '1050', 'Hijuela 1° Guevara'),
        (v_insp_rj, '1051', 'Hijuela 2° Guevara'),
        (v_insp_rj, '1052', 'Hijuela 3° Guevara'),
        (v_insp_rj, '1053', 'Hijuela 4° Guevara'),
        (v_insp_rj, '1054', 'Hijuela Allayme'),
        -- Rama Tajamar
        (v_insp_rt, '1070', 'Rama Tajamar'),
        (v_insp_rt, '1071', 'Hijuela Chimba'),
        (v_insp_rt, '1072', 'Ramo Manzano'),
        (v_insp_rt, '1073', 'Ramo Furlani'),
        (v_insp_rt, '1074', 'Hijuela Zapallar'),
        (v_insp_rt, '1075', 'Ramo Moyano'),
        (v_insp_rt, '1076', 'Ramo Plumerillo'),
        (v_insp_rt, '1077', 'Ramo Hoyos'),
        (v_insp_rt, '1078', 'Ramo Saez'),
        (v_insp_rt, '1079', 'Ramo Puebla'),
        (v_insp_rt, '1080', 'Ramo Torres'),
        (v_insp_rt, '1081', 'Ramo Cabrera'),
        (v_insp_rt, '1082', 'Ramo Bonfanti'),
        (v_insp_rt, '1083', 'Ramo Mascota'),
        (v_insp_rt, '1084', 'Ramo Cichitti'),
        (v_insp_rt, '1085', 'Toma Particular'),
        (v_insp_rt, '1086', 'Toma J. Monteavaro y otros'),
        (v_insp_rt, '1766', 'Vertientes Borbollon'),
        (v_insp_rt, '1912', 'Desague Alvarez Condarco'),
        -- Luján Sur Unificada
        (v_insp_ls, '1107', 'Canal Flores'),
        (v_insp_ls, '1108', 'Hijuela Quinteros'),
        (v_insp_ls, '1109', 'Hijuela Bella Vista'),
        (v_insp_ls, '1111', 'Hijuela Bella Vista'),
        (v_insp_ls, '1112', 'Canal Corvalan'),
        (v_insp_ls, '1113', 'Canal Santander'),
        (v_insp_ls, '1919', 'Concesión de desagues'),
        -- Asociación Primera Zona de riego (sin canal específico)
        (v_insp_apzr, '1020', 'Asociación Primera Zona de riego')
    ON CONFLICT (codigo_canal) DO NOTHING;
END $$;

-- ============================================================================
-- Fin
-- ============================================================================
