import type { PageLoad } from './$types';
import { listarSectores, listarTiposExpediente, listarInspecciones } from '$lib/api/catalogos';

export const load: PageLoad = async ({ url }) => {
	const [sectores, tipos, inspecciones] = await Promise.all([
		listarSectores(),
		listarTiposExpediente(),
		listarInspecciones()
	]);

	const reclamante = {
		nombre: url.searchParams.get('reclamante_nombre') ?? '',
		apellido: url.searchParams.get('reclamante_apellido') ?? '',
		dni: url.searchParams.get('reclamante_dni') ?? '',
		cc: url.searchParams.get('reclamante_cc') ?? '',
		pp: url.searchParams.get('reclamante_pp') ?? ''
	};

	const reclamoIdParam = url.searchParams.get('reclamo_id');
	const reclamo_id = reclamoIdParam ? Number(reclamoIdParam) : undefined;

	return { sectores, tipos, inspecciones, reclamante, reclamo_id };
};
