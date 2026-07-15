import type { PageLoad } from './$types';
import { obtenerReclamo, listarCanales, listarTomas, listarTiposReclamo, listarInspecciones } from '$lib/api/reclamos';
import { listarSectores } from '$lib/api/catalogos';

export const load: PageLoad = async ({ params }) => {
	const id = Number(params.id);
	const [reclamo, canales, tomas, tipos, inspecciones, sectores] = await Promise.all([
		obtenerReclamo(id),
		listarCanales(),
		listarTomas(),
		listarTiposReclamo(),
		listarInspecciones(),
		listarSectores()
	]);

	return { reclamo, canales, tomas, tipos, inspecciones, sectores };
};
