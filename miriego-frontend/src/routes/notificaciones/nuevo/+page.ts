import type { PageLoad } from './$types';
import { listarTiposNotificacion, listarMediosNotificacion } from '$lib/api/notificaciones';

export const load: PageLoad = async () => {
	const [tiposNotificacion, mediosNotificacion] = await Promise.all([
		listarTiposNotificacion(),
		listarMediosNotificacion()
	]);

	return { tiposNotificacion, mediosNotificacion };
};
