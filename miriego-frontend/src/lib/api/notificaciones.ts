import { apiFetch } from './client';
import { PUBLIC_API_URL } from '$env/static/public';
import type {
	Notificacion,
	NotificacionDetalle,
	NotificacionCreatePayload,
	TipoNotificacion,
	MedioNotificacion,
	PaginatedResponse
} from '$lib/types/notificacion';

export function listarNotificaciones(filtros?: {
	estado?: string;
	notificado_tipo?: string;
	q?: string;
	fecha_desde?: string;
	fecha_hasta?: string;
	page?: number;
	page_size?: number;
}) {
	const params = new URLSearchParams();
	if (filtros?.estado) params.set('estado', filtros.estado);
	if (filtros?.notificado_tipo) params.set('notificado_tipo', filtros.notificado_tipo);
	if (filtros?.q) params.set('q', filtros.q);
	if (filtros?.fecha_desde) params.set('fecha_desde', filtros.fecha_desde);
	if (filtros?.fecha_hasta) params.set('fecha_hasta', filtros.fecha_hasta);
	if (filtros?.page) params.set('page', String(filtros.page));
	if (filtros?.page_size) params.set('page_size', String(filtros.page_size));

	const query = params.toString() ? `?${params.toString()}` : '';
	return apiFetch<PaginatedResponse<Notificacion>>(`/notificaciones${query}`);
}

export function obtenerNotificacion(id: number) {
	return apiFetch<NotificacionDetalle>(`/notificaciones/${id}`);
}

export function crearNotificacion(payload: NotificacionCreatePayload) {
	return apiFetch<Notificacion>('/notificaciones', {
		method: 'POST',
		body: JSON.stringify(payload)
	});
}

export function actualizarNotificacion(
	id: number,
	payload: {
		estado?: string;
		tipo_notificacion_id?: number | null;
		medio_notificacion_id?: number | null;
		expediente_id?: number | null;
		notificado_nombre?: string;
		notificado_documento?: string;
		notificado_domicilio?: string;
		notificado_contacto?: string;
		motivo?: string;
		descripcion?: string;
		fecha_notificacion?: string;
		fecha_vencimiento_respuesta?: string;
		observaciones?: string;
	}
) {
	return apiFetch<Notificacion>(`/notificaciones/${id}`, {
		method: 'PATCH',
		body: JSON.stringify(payload)
	});
}

// --- Catálogos ---

export function listarTiposNotificacion() {
	return apiFetch<TipoNotificacion[]>('/catalogos/tipos-notificacion');
}

export function listarMediosNotificacion() {
	return apiFetch<MedioNotificacion[]>('/catalogos/medios-notificacion');
}

// --- Imprimir cédula ---

export async function imprimirNotificacion(id: number): Promise<void> {
	const res = await fetch(`${PUBLIC_API_URL}/notificaciones/${id}/imprimir`, { method: 'POST' });
	if (!res.ok) {
		const detalle = await res.text();
		let mensaje = detalle;
		try {
			const parsed = JSON.parse(detalle);
			if (parsed.detail) mensaje = parsed.detail;
		} catch { /* no era JSON */ }
		throw new Error(mensaje);
	}
	const blob = await res.blob();
	const url = URL.createObjectURL(blob);
	const a = document.createElement('a');
	a.href = url;
	a.download = `cedula_${id}.docx`;
	document.body.appendChild(a);
	a.click();
	a.remove();
	URL.revokeObjectURL(url);
}
