import { apiFetch } from './client';
import type {
	Reclamo,
	ReclamoDetalle,
	ReclamoCreatePayload,
	ReclamoComentario,
	ReclamoAdjunto,
	CategoriaReclamo,
	TipoReclamo,
	Canal,
	Toma,
	Inspeccion
} from '$lib/types/reclamo';

export function listarReclamos(filtros?: {
	estado?: string;
	canal_id?: number;
	toma_id?: number;
	tipo_id?: number;
	prioridad?: string;
	q?: string;
	fecha_desde?: string;
	fecha_hasta?: string;
}) {
	const params = new URLSearchParams();
	if (filtros?.estado) params.set('estado', filtros.estado);
	if (filtros?.canal_id) params.set('canal_id', String(filtros.canal_id));
	if (filtros?.toma_id) params.set('toma_id', String(filtros.toma_id));
	if (filtros?.tipo_id) params.set('tipo_id', String(filtros.tipo_id));
	if (filtros?.prioridad) params.set('prioridad', filtros.prioridad);
	if (filtros?.q) params.set('q', filtros.q);
	if (filtros?.fecha_desde) params.set('fecha_desde', filtros.fecha_desde);
	if (filtros?.fecha_hasta) params.set('fecha_hasta', filtros.fecha_hasta);

	const query = params.toString() ? `?${params.toString()}` : '';
	return apiFetch<Reclamo[]>(`/reclamos${query}`);
}

export function obtenerReclamo(id: number) {
	return apiFetch<ReclamoDetalle>(`/reclamos/${id}`);
}

export function crearReclamo(payload: ReclamoCreatePayload) {
	return apiFetch<Reclamo>('/reclamos', {
		method: 'POST',
		body: JSON.stringify(payload)
	});
}

export function actualizarReclamo(
	id: number,
	payload: {
		estado?: string;
		prioridad?: string;
		asignado_a?: number;
		expediente_id?: number | null;
		titulo?: string;
		descripcion?: string;
		reclamante_nombre?: string;
		reclamante_apellido?: string;
		reclamante_dni?: string;
		reclamante_telefono?: string;
		reclamante_email?: string;
		reclamante_cc?: string;
		reclamante_pp?: string;
		direccion_manual?: string;
		comentario?: string;
		sector_actual_id?: number;
	}
) {
	return apiFetch<Reclamo>(`/reclamos/${id}`, {
		method: 'PATCH',
		body: JSON.stringify(payload)
	});
}

export function agregarComentario(
	reclamoId: number,
	payload: { comentario: string; es_interno?: boolean }
) {
	return apiFetch<ReclamoComentario>(`/reclamos/${reclamoId}/comentarios`, {
		method: 'POST',
		body: JSON.stringify({ usuario_id: 1, rol_usuario: 'administrador', ...payload }) // TODO: reemplazar con usuario autenticado en cada lugar donde use este id=1 fijo
	});
}

export function agregarAdjunto(
	reclamoId: number,
	payload: { archivo_url: string; tipo_archivo?: string; descripcion?: string }
) {
	return apiFetch<ReclamoAdjunto>(`/reclamos/${reclamoId}/adjuntos`, {
		method: 'POST',
		body: JSON.stringify(payload)
	});
}

// --- Catálogos ---

export function listarCategoriasReclamo() {
	return apiFetch<CategoriaReclamo[]>('/catalogos/categorias-reclamo');
}

export function listarTiposReclamo() {
	return apiFetch<TipoReclamo[]>('/catalogos/tipos-reclamo');
}

export function listarCanales() {
	return apiFetch<Canal[]>('/catalogos/canales');
}

export function listarTomas() {
	return apiFetch<Toma[]>('/catalogos/tomas');
}

export function listarInspecciones() {
	return apiFetch<Inspeccion[]>('/catalogos/inspecciones');
}
