// Tipos TypeScript para el módulo de Reclamos.
// Reflejan los schemas Pydantic del backend (app/schemas/reclamo.py).

export type EstadoReclamo =
	| 'nuevo'
	| 'recibido'
	| 'en_revision'
	| 'asignado'
	| 'en_proceso'
	| 'resuelto'
	| 'cerrado'
	| 'rechazado'
	| 'derivado'
	| 'derivado_expediente'
	| 'pendiente_informacion'
	| 'cancelado'
	| 'reabierto';

export type PrioridadReclamo = 'baja' | 'media' | 'alta' | 'critica';

// --- Catálogos / jerarquía de riego ---

export interface Cuenca {
	id: number;
	nombre: string;
}

export interface Asociacion {
	id: number;
	nombre: string;
	cuenca_id: number;
}

export interface Inspeccion {
	id: number;
	nombre: string;
	inspector?: string | null;
	asociacion_id: number;
}

export interface Canal {
	id: number;
	codigo_canal: string;
	nombre: string;
	inspeccion_id: number;
}

export interface Toma {
	id: number;
	codigo_toma: string;
	nombre?: string | null;
	canal_id: number;
}

export interface CategoriaReclamo {
	id: number;
	nombre: string;
}

export interface TipoReclamo {
	id: number;
	nombre: string;
	categoria_id: number;
	prioridad_sugerida: PrioridadReclamo;
}

// --- Reclamo ---

export interface Reclamo {
	id: number;
	codigo_reclamo: string;
	usuario_id: number;
	tipo_id: number;
	categoria_id: number;
	prioridad: PrioridadReclamo;
	estado: EstadoReclamo;
	titulo: string;
	descripcion: string;

	regante_id?: number | null;
	ccpp_id?: number | null;
	toma_id?: number | null;
	canal_id?: number | null;
	inspeccion_id?: number | null;
	asociacion_id?: number | null;
	cuenca_id?: number | null;
	tomero_id?: number | null;

	latitud?: number | null;
	longitud?: number | null;
	direccion_manual?: string | null;

	es_regante: boolean;
	reclamante_nombre?: string | null;
	reclamante_apellido?: string | null;
	reclamante_dni?: string | null;
	reclamante_telefono?: string | null;
	reclamante_email?: string | null;
	reclamante_cc?: string | null;
	reclamante_pp?: string | null;

	fecha_creacion: string;
	fecha_primera_respuesta?: string | null;
	fecha_resolucion?: string | null;
	fecha_cierre?: string | null;
	fecha_limite_respuesta?: string | null;

	asignado_a?: number | null;
	expediente_id?: number | null;
	numero_expediente?: string | null;
}

export interface ReclamoComentario {
	id: number;
	reclamo_id: number;
	usuario_id: number;
	rol_usuario: string;
	comentario: string;
	es_interno: boolean;
	fecha: string;
}

export interface ReclamoAdjunto {
	id: number;
	reclamo_id: number;
	archivo_url: string;
	tipo_archivo?: string | null;
	descripcion?: string | null;
	fecha: string;
}

export interface ReclamoHistorial {
	id: number;
	reclamo_id: number;
	usuario_id?: number | null;
	accion: string;
	estado_anterior?: string | null;
	estado_nuevo?: string | null;
	observacion?: string | null;
	fecha: string;
}

export interface ReclamoDetalle extends Reclamo {
	comentarios: ReclamoComentario[];
	adjuntos: ReclamoAdjunto[];
	historial: ReclamoHistorial[];
}

export interface ReclamoCreatePayload {
	tipo_id: number;
	categoria_id: number;
	titulo: string;
	descripcion: string;
	usuario_id?: number;
	prioridad?: PrioridadReclamo;
	toma_id?: number;
	canal_id?: number;
	inspeccion_id?: number;
	latitud?: number;
	longitud?: number;
	direccion_manual?: string;
	es_regante?: boolean;
	reclamante_nombre?: string;
	reclamante_apellido?: string;
	reclamante_dni?: string;
	reclamante_telefono?: string;
	reclamante_email?: string;
	reclamante_cc?: string;
	reclamante_pp?: string;
}

export interface PaginatedResponse<T> {
	items: T[];
	total: number;
	page: number;
	page_size: number;
}
