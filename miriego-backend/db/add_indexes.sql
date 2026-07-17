-- Índices faltantes para mejorar rendimiento de búsquedas y filtros
-- en los endpoints de listado de expedientes y reclamos.

-- Expedientes: búsqueda por número (ILIKE en filtro de texto)
CREATE INDEX IF NOT EXISTS idx_expedientes_numero ON miriego.expedientes(numero_expediente);

-- Expedientes: ORDER BY en listado
CREATE INDEX IF NOT EXISTS idx_expedientes_fecha_actualizacion ON miriego.expedientes(fecha_ultima_actualizacion);

-- Expedientes: filtro por inspección (agregado post-creación, sin índice)
CREATE INDEX IF NOT EXISTS idx_expedientes_inspeccion ON miriego.expedientes(inspeccion_id);

-- Reclamos: búsqueda por código (ILIKE en filtro de texto)
CREATE INDEX IF NOT EXISTS idx_reclamos_codigo ON miriego.reclamos(codigo_reclamo);

-- Reclamos: filtro por tipo
CREATE INDEX IF NOT EXISTS idx_reclamos_tipo ON miriego.reclamos(tipo_id);

-- Pases: subquery MAX(fecha_vencimiento) para ultimo_vencimiento
CREATE INDEX IF NOT EXISTS idx_pases_fecha_vencimiento ON miriego.pases(fecha_vencimiento);
