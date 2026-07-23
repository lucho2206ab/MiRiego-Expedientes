// Tipos TypeScript para el módulo de Notificaciones.
// Reflejan los schemas Pydantic del backend (app/schemas/notificacion.py).

export type NotificadoTipo = 'regante' | 'tercero';

export type EstadoNotificacion =
	| 'emitida'
	| 'notificada'
	| 'respondida'
	| 'vencida'
	| 'cumplida'
	| 'cerrada';

// --- Catálogos ---

export interface TipoNotificacion {
	id: number;
	nombre: string;
}

export interface MedioNotificacion {
	id: number;
	nombre: string;
}

// --- Notificación ---

export interface Notificacion {
	id: number;
	codigo_notificacion: string;
	usuario_id: number;

	tipo_notificacion_id?: number | null;
	medio_notificacion_id?: number | null;
	expediente_id?: number | null;

	notificado_tipo: NotificadoTipo;
	cc?: string | null;
	pp?: string | null;
	inspeccion_id?: number | null;
	notificado_nombre?: string | null;
	notificado_documento?: string | null;
	notificado_domicilio?: string | null;
	notificado_contacto?: string | null;

	motivo: string;
	descripcion: string;

	fecha_emision?: string | null;
	fecha_notificacion?: string | null;
	fecha_vencimiento_respuesta?: string | null;

	estado: EstadoNotificacion;
	observaciones?: string | null;

	numero_expediente?: string | null;
}

export interface NotificacionDetalle extends Notificacion {
	inspeccion_nombre?: string | null;
	inspector_nombre?: string | null;
}

export interface NotificacionCreatePayload {
	tipo_notificacion_id?: number | null;
	medio_notificacion_id?: number | null;
	expediente_id?: number | null;
	notificado_tipo: NotificadoTipo;
	cc?: string;
	pp?: string;
	inspeccion_id?: number;
	notificado_nombre?: string;
	notificado_documento?: string;
	notificado_domicilio?: string;
	notificado_contacto?: string;
	motivo: string;
	descripcion: string;
	fecha_vencimiento_respuesta?: string;
	observaciones?: string;
}

export interface PaginatedResponse<T> {
	items: T[];
	total: number;
	page: number;
	page_size: number;
}
