-- Migración: agregar columna fecha_limite_respuesta a reclamos (SLA)
-- Ejecutar: psql -U postgres -d miriego -f miriego-backend/db/add_sla_reclamos.sql

ALTER TABLE miriego.reclamos
ADD COLUMN IF NOT EXISTS fecha_limite_respuesta timestamp with time zone;
