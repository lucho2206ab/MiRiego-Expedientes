import type { PageLoad } from './$types';
import { listarExpedientes } from '$lib/api/expedientes';
import { listarSectores } from '$lib/api/catalogos';

// `load` corre antes de renderizar la página: trae los datos desde
// la API de FastAPI para que la página ya llegue con la info lista.
export const load: PageLoad = async ({ url }) => {
	const q = url.searchParams.get('q') || undefined;
	const fecha_desde = url.searchParams.get('fecha_desde') || undefined;
	const fecha_hasta = url.searchParams.get('fecha_hasta') || undefined;
	const sector_id = url.searchParams.get('sector_id') ? Number(url.searchParams.get('sector_id')) : undefined;
	const estado = url.searchParams.get('estado') || undefined;

	const [expedientes, sectores] = await Promise.all([
		listarExpedientes({ q, fecha_desde, fecha_hasta, sector_id, estado }),
		listarSectores()
	]);

	return { expedientes, sectores, filtros: { q, fecha_desde, fecha_hasta, sector_id, estado } };
};
