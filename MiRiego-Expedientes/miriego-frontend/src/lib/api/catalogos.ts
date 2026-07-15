import { apiFetch } from './client';
import type { Sector, TipoExpediente, Inspeccion } from '$lib/types/expediente';

export function listarSectores() {
	return apiFetch<Sector[]>('/catalogos/sectores');
}

export function listarTiposExpediente() {
	return apiFetch<TipoExpediente[]>('/catalogos/tipos-expediente');
}

export function listarInspecciones() {
	return apiFetch<Inspeccion[]>('/catalogos/inspecciones');
}
