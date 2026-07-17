-- Agregar campos de contacto del iniciador (email y telefono)
ALTER TABLE miriego.expedientes
    ADD COLUMN IF NOT EXISTS iniciador_email VARCHAR(150),
    ADD COLUMN IF NOT EXISTS iniciador_telefono VARCHAR(40);
