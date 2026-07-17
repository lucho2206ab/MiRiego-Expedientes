import type { PageLoad } from './$types';
import { listarReclamos, listarCanales, listarTomas, listarTiposReclamo, listarInspecciones } from '$lib/api/reclamos';

export const load: PageLoad = async ({ url }) => {
	const estado = url.searchParams.get('estado') ?? undefined;
	const inspeccionId = url.searchParams.get('inspeccion_id') ? Number(url.searchParams.get('inspeccion_id')) : undefined;
	const canalId = url.searchParams.get('canal_id') ? Number(url.searchParams.get('canal_id')) : undefined;
	const tipoId = url.searchParams.get('tipo_id') ? Number(url.searchParams.get('tipo_id')) : undefined;
	const prioridad = url.searchParams.get('prioridad') ?? undefined;
	const q = url.searchParams.get('q') ?? undefined;
	const fechaDesde = url.searchParams.get('fecha_desde') ?? undefined;
	const fechaHasta = url.searchParams.get('fecha_hasta') ?? undefined;
	const page = Number(url.searchParams.get('page')) || 1;

	const PAGE_SIZE = 20;

	const [paginado, canales, tomas, tipos, inspecciones] = await Promise.all([
		listarReclamos({ estado, inspeccion_id: inspeccionId, canal_id: canalId, tipo_id: tipoId, prioridad, q, fecha_desde: fechaDesde, fecha_hasta: fechaHasta, page, page_size: PAGE_SIZE }),
		listarCanales(),
		listarTomas(),
		listarTiposReclamo(),
		listarInspecciones()
	]);

	return {
		reclamos: paginado.items,
		total: paginado.total,
		page: paginado.page,
		pageSize: paginado.page_size,
		canales, tomas, tipos, inspecciones,
		filtros: { inspeccion_id: inspeccionId, canal_id: canalId, tipo_id: tipoId, prioridad, q, fecha_desde: fechaDesde, fecha_hasta: fechaHasta }
	};
};
