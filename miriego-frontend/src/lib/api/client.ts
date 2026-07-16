import { PUBLIC_API_URL } from '$env/static/public';

// Wrapper chico sobre fetch para no repetir manejo de errores en
// cada llamada. Todos los módulos de api/ (expedientes.ts, etc.)
// usan esta función en vez de llamar a fetch directamente.
export async function apiFetch<T>(
	path: string,
	options: RequestInit = {}
): Promise<T> {
	const res = await fetch(`${PUBLIC_API_URL}${path}`, {
		headers: {
			'Content-Type': 'application/json',
			...options.headers
		},
		...options
	});

	if (!res.ok) {
		const detalle = await res.text();
		throw new Error(`Error ${res.status} en ${path}: ${detalle}`);
	}

	// Los endpoints que no devuelven cuerpo (204) no intentan parsear JSON
	if (res.status === 204) return undefined as T;

	return res.json() as Promise<T>;
}
