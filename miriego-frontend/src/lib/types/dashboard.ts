// Tipos TypeScript para el módulo Dashboard.

export interface SectorConteo {
	sector_id: number;
	sector_nombre: string;
	total: number;
}

export interface ExpedienteVencido {
	id: number;
	numero_expediente: string;
	asunto: string;
	estado: string;
	fecha_vencimiento_effectiva: string | null;
}

export interface InspeccionConteo {
	inspeccion_id: number;
	inspeccion_nombre: string;
	total: number;
}

export interface ReclamoVencido {
	id: number;
	codigo_reclamo: string;
	titulo: string;
	prioridad: string;
	estado: string;
	fecha_limite_respuesta: string | null;
}
