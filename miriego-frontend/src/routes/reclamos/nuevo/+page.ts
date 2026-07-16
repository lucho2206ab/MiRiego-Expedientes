import type { PageLoad } from './$types';
import {
	listarCategoriasReclamo,
	listarTiposReclamo,
	listarCanales,
	listarTomas,
	listarInspecciones
} from '$lib/api/reclamos';

export const load: PageLoad = async () => {
	const [categorias, tipos, canales, tomas, inspecciones] = await Promise.all([
		listarCategoriasReclamo(),
		listarTiposReclamo(),
		listarCanales(),
		listarTomas(),
		listarInspecciones()
	]);

	return { categorias, tipos, canales, tomas, inspecciones };
};
