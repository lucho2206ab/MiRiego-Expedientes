import type { PageLoad } from './$types';
import { listarSectores } from '$lib/api/catalogos';
import { listarInspecciones } from '$lib/api/reclamos';

export const load: PageLoad = async () => {
	const [sectores, inspecciones] = await Promise.all([
		listarSectores(),
		listarInspecciones()
	]);

	return { sectores, inspecciones };
};
