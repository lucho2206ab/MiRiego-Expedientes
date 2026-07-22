import { apiFetch } from './client';
import type {
	Expediente,
	ExpedienteDetalle,
	ExpedienteCreatePayload,
	ExpedienteUpdatePayload,
	PaginatedResponse,
	Pase,
	Nota
} from '$lib/types/expediente';

export function listarExpedientes(filtros?: { sector_id?: number; estado?: string; q?: string; fecha_desde?: string; fecha_hasta?: string; page?: number; page_size?: number }) {
	const params = new URLSearchParams();
	if (filtros?.sector_id) params.set('sector_id', String(filtros.sector_id));
	if (filtros?.estado) params.set('estado', filtros.estado);
	if (filtros?.q) params.set('q', filtros.q);
	if (filtros?.fecha_desde) params.set('fecha_desde', filtros.fecha_desde);
	if (filtros?.fecha_hasta) params.set('fecha_hasta', filtros.fecha_hasta);
	if (filtros?.page) params.set('page', String(filtros.page));
	if (filtros?.page_size) params.set('page_size', String(filtros.page_size));

	const query = params.toString() ? `?${params.toString()}` : '';
	return apiFetch<PaginatedResponse<Expediente>>(`/expedientes${query}`);
}

export function obtenerExpediente(id: number) {
	return apiFetch<ExpedienteDetalle>(`/expedientes/${id}`);
}

export function crearExpediente(payload: ExpedienteCreatePayload) {
	return apiFetch<Expediente>('/expedientes', {
		method: 'POST',
		body: JSON.stringify(payload)
	});
}

export function actualizarExpediente(id: number, payload: ExpedienteUpdatePayload) {
	return apiFetch<Expediente>(`/expedientes/${id}`, {
		method: 'PUT',
		body: JSON.stringify(payload)
	});
}

export function generarPase(
	expedienteId: number,
	payload: {
		sector_destino_id?: number;
		sector_nombre?: string;
		motivo?: string;
		observaciones?: string;
		fecha_vencimiento?: string;
		inspeccion_id?: number;
		subsector_mesa_entradas?: string;
	}
) {
	// El pase se aplica de inmediato en el backend (el trigger de la
	// base mueve sector_actual_id y el estado del expediente al toque).
	return apiFetch<Pase>(`/expedientes/${expedienteId}/pases`, {
		method: 'POST',
		body: JSON.stringify(payload)
	});
}

export function agregarNota(
	expedienteId: number,
	payload: { sector_id: number; contenido: string; es_interna?: boolean }
) {
	return apiFetch<Nota>(`/expedientes/${expedienteId}/notas`, {
		method: 'POST',
		body: JSON.stringify(payload)
	});
}
