import type { PageLoad } from './$types';
import { obtenerNotificacion } from '$lib/api/notificaciones';

export const load: PageLoad = async ({ params }) => {
	const notificacion = await obtenerNotificacion(Number(params.id));
	return { notificacion };
};
