import { apiFetch } from './client';
import type {
	SectorConteo,
	ExpedienteVencido,
	InspeccionConteo,
	ReclamoVencido
} from '$lib/types/dashboard';

export function expedientesVencimientos(params: {
	sector_id?: number;
	estado?: string;
	dias_umbral?: number;
}) {
	const searchParams = new URLSearchParams();
	if (params.sector_id) searchParams.set('sector_id', String(params.sector_id));
	if (params.estado) searchParams.set('estado', params.estado);
	if (params.dias_umbral) searchParams.set('dias_umbral', String(params.dias_umbral));
	const qs = searchParams.toString();
	return apiFetch<SectorConteo[] | ExpedienteVencido[]>(`/dashboard/expedientes-vencimientos${qs ? `?${qs}` : ''}`);
}

export function reclamosVencimientos(params: {
	inspeccion_id?: number;
	estado?: string;
	horas_umbral?: number;
}) {
	const searchParams = new URLSearchParams();
	if (params.inspeccion_id) searchParams.set('inspeccion_id', String(params.inspeccion_id));
	if (params.estado) searchParams.set('estado', params.estado);
	if (params.horas_umbral) searchParams.set('horas_umbral', String(params.horas_umbral));
	const qs = searchParams.toString();
	return apiFetch<InspeccionConteo[] | ReclamoVencido[]>(`/dashboard/reclamos-vencimientos${qs ? `?${qs}` : ''}`);
}
