// Estos tipos reflejan 1 a 1 los schemas Pydantic del backend
// (app/schemas/expediente.py). Si cambiás algo en el backend,
// actualizá acá también hasta que automaticemos la generación
// de tipos (se puede hacer después con openapi-typescript).

export type EstadoExpediente =
	| 'iniciado'
	| 'en_tramite'
	| 'pase_pendiente'
	| 'pendiente_firma'
	| 'observado'
	| 'resuelto'
	| 'archivado'
	| 'anulado';

export type EstadoPase = 'enviado' | 'recibido' | 'rechazado';

export interface Sector {
	id: number;
	nombre: string;
	descripcion?: string | null;
}

export interface TipoExpediente {
	id: number;
	nombre: string;
	descripcion?: string | null;
}

export interface Expediente {
	id: number;
	numero_expediente: string;
	tipo_id: number;
	asunto: string;
	descripcion?: string | null;
	iniciador_nombre: string;
	iniciador_dni_cuit?: string | null;
	iniciador_cc?: string | null;
	iniciador_pp?: string | null;
	iniciador_email?: string | null;
	iniciador_telefono?: string | null;
	regante_id?: number | null;
	inspeccion_id?: number | null;
	sector_actual_id: number;
	estado: EstadoExpediente;
	gde_numero?: string | null;
	infogov_numero?: string | null;
	expediente_acumulado_numero?: string | null;
	fecha_inicio: string;
	fecha_ultima_actualizacion: string;
	fecha_resolucion?: string | null;
	fecha_archivo?: string | null;
	fecha_vencimiento?: string | null;
	ultimo_vencimiento?: string | null;
}

export interface Pase {
	id: number;
	expediente_id: number;
	sector_origen_id: number;
	sector_destino_id: number;
	usuario_id?: number | null;
	motivo?: string | null;
	observaciones?: string | null;
	inspeccion_id?: number | null;
	subsector_mesa_entradas?: string | null;
	usuario_asignado_id?: number | null;
	estado: EstadoPase;
	fecha_envio: string;
	fecha_recepcion?: string | null;
	fecha_vencimiento?: string | null;
}

export interface Nota {
	id: number;
	expediente_id: number;
	sector_id: number;
	usuario_id?: number | null;
	contenido: string;
	es_interna: boolean;
	fecha: string;
}

export interface ExpedienteDetalle extends Expediente {
	pases: Pase[];
	notas: Nota[];
}

export interface ExpedienteCreatePayload {
	numero_expediente: string;
	tipo_id: number;
	asunto: string;
	descripcion?: string;
	iniciador_nombre: string;
	iniciador_dni_cuit?: string;
	iniciador_cc?: string;
	iniciador_pp?: string;
	iniciador_email?: string;
	iniciador_telefono?: string;
	regante_id?: number;
	inspeccion_id?: number;
	sector_actual_id?: number;
	sector_nombre?: string;
	gde_numero?: string;
	infogov_numero?: string;
	expediente_acumulado_numero?: string;
	fecha_inicio?: string;
	fecha_vencimiento?: string;
	reclamo_id?: number;
}

export interface ExpedienteUpdatePayload {
	numero_expediente?: string;
	asunto?: string;
	descripcion?: string;
	iniciador_nombre?: string;
	iniciador_dni_cuit?: string;
	iniciador_cc?: string;
	iniciador_pp?: string;
	iniciador_email?: string;
	iniciador_telefono?: string;
	gde_numero?: string;
	infogov_numero?: string;
	expediente_acumulado_numero?: string;
	fecha_vencimiento?: string;
}

export interface Inspeccion {
	id: number;
	nombre: string;
	inspector?: string | null;
	asociacion_id: number;
}

export type SubsectorMesaEntradas = 'Casilla de Vencimiento' | 'Notificador' | 'Reserva' | 'Archivo Mesa de Entradas' | 'Archivo Deposito' | 'Recepcion';

export interface PaginatedResponse<T> {
	items: T[];
	total: number;
	page: number;
	page_size: number;
}
