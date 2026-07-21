import type { PageLoad } from './$types';
import { listarNotificaciones, listarTiposNotificacion, listarMediosNotificacion } from '$lib/api/notificaciones';

export const load: PageLoad = async ({ url }) => {
	const estado = url.searchParams.get('estado') ?? undefined;
	const notificadoTipo = url.searchParams.get('notificado_tipo') ?? undefined;
	const q = url.searchParams.get('q') ?? undefined;
	const fechaDesde = url.searchParams.get('fecha_desde') ?? undefined;
	const fechaHasta = url.searchParams.get('fecha_hasta') ?? undefined;
	const page = Number(url.searchParams.get('page')) || 1;

	const PAGE_SIZE = 20;

	const [paginado, tiposNotificacion, mediosNotificacion] = await Promise.all([
		listarNotificaciones({ estado, notificado_tipo: notificadoTipo, q, fecha_desde: fechaDesde, fecha_hasta: fechaHasta, page, page_size: PAGE_SIZE }),
		listarTiposNotificacion(),
		listarMediosNotificacion()
	]);

	return {
		notificaciones: paginado.items,
		total: paginado.total,
		page: paginado.page,
		pageSize: paginado.page_size,
		tiposNotificacion,
		mediosNotificacion,
		filtros: { estado, notificado_tipo: notificadoTipo, q, fecha_desde: fechaDesde, fecha_hasta: fechaHasta }
	};
};
