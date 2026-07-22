-- Agregar tipo de expediente "Tramites generales"
INSERT INTO miriego.tipos_expediente (nombre) VALUES
    ('Tramites generales')
ON CONFLICT (nombre) DO NOTHING;
