import type { PageLoad } from './$types';
import { obtenerExpediente } from '$lib/api/expedientes';
import { listarSectores, listarInspecciones } from '$lib/api/catalogos';

export const load: PageLoad = async ({ params }) => {
	const id = Number(params.id);
	const [expediente, sectores, inspecciones] = await Promise.all([
		obtenerExpediente(id),
		listarSectores(),
		listarInspecciones()
	]);

	return { expediente, sectores, inspecciones };
};
