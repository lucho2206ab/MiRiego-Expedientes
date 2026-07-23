import type { PageLoad } from './$types';
import { listarTiposNotificacion, listarMediosNotificacion } from '$lib/api/notificaciones';
import { listarInspecciones } from '$lib/api/catalogos';

export const load: PageLoad = async () => {
	const [tiposNotificacion, mediosNotificacion, inspecciones] = await Promise.all([
		listarTiposNotificacion(),
		listarMediosNotificacion(),
		listarInspecciones()
	]);

	return { tiposNotificacion, mediosNotificacion, inspecciones };
};
