<script lang="ts">
	import type { PageData } from './$types';
	import { goto } from '$app/navigation';
	import { crearReclamo } from '$lib/api/reclamos';
	import type { ReclamoCreatePayload } from '$lib/types/reclamo';

	export let data: PageData;

	// Identificación del reclamante
	let esRegante = true;

	// Campos regante
	let cc = '';
	let pp = '';
	let nombre = '';
	let apellido = '';
	let dni = '';
	let telefono = '';
	let email = '';
	let direccion = '';

	// Clasificación
	let tipo_id: number | undefined;
	let prioridad: string = 'media';
	let titulo = '';
	let descripcion = '';

	// Ubicación (vecino)
	let direccion_manual = '';
	let latitud: number | undefined;
	let longitud: number | undefined;

	// Asignación manual de inspección (cuando no se resuelve automáticamente)
	let inspeccion_id: number | undefined;

	let enviando = false;
	let error = '';

	$: esReganteSeleccionado = esRegante === true;

	function validateEmail(value: string): boolean {
		if (!value.trim()) return false;
		const pattern = /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/;
		return pattern.test(value.trim());
	}

	function validateDni(value: string): boolean {
		if (!value.trim()) return false;
		const digits = value.trim();
		return /^\d{7,8}$/.test(digits);
	}

	async function onSubmit() {
		if (!tipo_id) {
			error = 'Elegí un tipo de reclamo.';
			return;
		}
		if (!titulo.trim() || !descripcion.trim()) {
			error = 'Completá título y descripción.';
			return;
		}

		// Validaciones por tipo de reclamante
		if (esReganteSeleccionado) {
			if (!cc.trim()) {
				error = 'Completá el código de Cauce (CC).';
				return;
			}
			if (!pp.trim()) {
				error = 'Completá el Padrón Parcial (PP).';
				return;
			}
			if (!nombre.trim()) {
				error = 'Completá el nombre.';
				return;
			}
			if (!apellido.trim()) {
				error = 'Completá el apellido.';
				return;
			}
			if (!validateDni(dni)) {
				error = 'El DNI debe contener entre 7 y 8 dígitos numéricos.';
				return;
			}
			if (!validateEmail(email)) {
				error = 'Ingresá un email válido.';
				return;
			}
			if (!direccion.trim()) {
				error = 'Completá la dirección.';
				return;
			}
		} else {
			// Vecino / no regante
			if (!nombre.trim()) {
				error = 'Completá el nombre.';
				return;
			}
			if (!apellido.trim()) {
				error = 'Completá el apellido.';
				return;
			}
			if (!validateEmail(email)) {
				error = 'El email es obligatorio para poder notificarte del estado del reclamo.';
				return;
			}
			if (!inspeccion_id) {
				error = 'Seleccioná la inspección a la que se deriva el reclamo.';
				return;
			}
		}

		enviando = true;
		error = '';

		try {
			const tipoSeleccionado = data.tipos.find((t) => t.id === tipo_id);
			const categoriaId = tipoSeleccionado?.categoria_id ?? 1;

			const payload: ReclamoCreatePayload = {
				tipo_id,
				categoria_id: categoriaId,
				prioridad: prioridad as ReclamoCreatePayload['prioridad'],
				titulo: titulo.toUpperCase(),
				descripcion: descripcion.toUpperCase(),
				es_regante: esReganteSeleccionado,
				reclamante_nombre: nombre ? nombre.toUpperCase() : undefined,
				reclamante_apellido: apellido ? apellido.toUpperCase() : undefined,
				reclamante_dni: dni || undefined,
				reclamante_telefono: telefono || undefined,
				reclamante_email: email || undefined,
				reclamante_cc: esReganteSeleccionado ? (cc ? cc.toUpperCase() : undefined) : undefined,
				reclamante_pp: esReganteSeleccionado ? (pp ? pp.toUpperCase() : undefined) : undefined,
				inspeccion_id: inspeccion_id ?? undefined,
				latitud: latitud ?? undefined,
				longitud: longitud ?? undefined,
				direccion_manual: esReganteSeleccionado ? (direccion ? direccion.toUpperCase() : undefined) : (direccion_manual ? direccion_manual.toUpperCase() : undefined)
			};

			const nuevo = await crearReclamo(payload);
			await goto(`/reclamos/${nuevo.id}`);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Error al crear el reclamo';
		} finally {
			enviando = false;
		}
	}

	function usarMiUbicacion() {
		if (!navigator.geolocation) {
			error = 'Tu navegador no soporta geolocalización.';
			return;
		}
		navigator.geolocation.getCurrentPosition(
			(pos) => {
				latitud = pos.coords.latitude;
				longitud = pos.coords.longitude;
			},
			() => {
				error = 'No se pudo obtener la ubicación. Ingresá la dirección manualmente.';
			}
		);
	}
</script>

<h1 class="text-2xl font-bold mb-4">Nuevo reclamo</h1>

<form on:submit|preventDefault={onSubmit}>
	<!-- Identificación del reclamante -->
	<fieldset class="border border-border rounded-lg p-4 mt-4">
		<legend class="font-semibold px-2">¿Quién hace el reclamo?</legend>

		<div class="flex gap-6 mt-1">
			<label class="flex items-center gap-2 text-sm cursor-pointer">
				<input type="radio" name="es-regante" value={true} bind:group={esRegante} /> Regante
			</label>
			<label class="flex items-center gap-2 text-sm cursor-pointer">
				<input type="radio" name="es-regante" value={false} bind:group={esRegante} /> Vecino / no regante
			</label>
		</div>

		{#if esReganteSeleccionado}
			<!-- Campos Regante -->
			<div class="grid grid-cols-2 gap-3 mt-4">
				<div>
					<label for="reg-cc" class="block text-sm font-medium mb-1">CC (Código de Cauce) *</label>
					<input id="reg-cc" bind:value={cc} required placeholder="Ej: 1038" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
				<div>
					<label for="reg-pp" class="block text-sm font-medium mb-1">PP (Padrón Parcial) *</label>
					<input id="reg-pp" bind:value={pp} required placeholder="Ej: 00123" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>

				<div>
					<label for="reg-nombre" class="block text-sm font-medium mb-1">Nombre *</label>
					<input id="reg-nombre" bind:value={nombre} required placeholder="Nombre" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
				<div>
					<label for="reg-apellido" class="block text-sm font-medium mb-1">Apellido *</label>
					<input id="reg-apellido" bind:value={apellido} required placeholder="Apellido" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
				<div>
					<label for="reg-dni" class="block text-sm font-medium mb-1">DNI * (7-8 dígitos)</label>
					<input id="reg-dni" bind:value={dni} required placeholder="Ej: 12345678" maxlength="8" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
				<div>
					<label for="reg-telefono" class="block text-sm font-medium mb-1">Teléfono</label>
					<input id="reg-telefono" bind:value={telefono} placeholder="Opcional" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
				<div class="col-span-2">
					<label for="reg-email" class="block text-sm font-medium mb-1">Email *</label>
					<input id="reg-email" type="email" bind:value={email} required placeholder="ejemplo@correo.com" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
				<div class="col-span-2">
					<label for="reg-direccion" class="block text-sm font-medium mb-1">Dirección *</label>
					<input id="reg-direccion" bind:value={direccion} required placeholder="Dirección completa" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
			</div>
		{:else}
			<!-- Campos Vecino / no regante -->
			<div class="grid grid-cols-2 gap-3 mt-4">
				<div>
					<label for="vec-nombre" class="block text-sm font-medium mb-1">Nombre *</label>
					<input id="vec-nombre" bind:value={nombre} required placeholder="Nombre" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
				<div>
					<label for="vec-apellido" class="block text-sm font-medium mb-1">Apellido *</label>
					<input id="vec-apellido" bind:value={apellido} required placeholder="Apellido" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
				<div class="col-span-2">
					<label for="vec-email" class="block text-sm font-medium mb-1">Email * (para notificaciones del estado del reclamo)</label>
					<input id="vec-email" type="email" bind:value={email} required placeholder="ejemplo@correo.com" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
				<div>
					<label for="vec-telefono" class="block text-sm font-medium mb-1">Teléfono</label>
					<input id="vec-telefono" bind:value={telefono} placeholder="Opcional" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
				<div>
					<label for="vec-dni" class="block text-sm font-medium mb-1">DNI</label>
					<input id="vec-dni" bind:value={dni} placeholder="Opcional" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
			</div>
		{/if}
	</fieldset>

	<!-- Clasificación -->
	<div class="mt-4">
		<label for="tipo" class="block text-sm font-medium mb-1">Tipo de reclamo *</label>
		<select id="tipo" bind:value={tipo_id} required class="w-full px-3 py-2 border border-border rounded-md text-sm">
			<option value={undefined} disabled selected>Seleccionar...</option>
			{#each data.tipos as tipo}
				<option value={tipo.id}>{tipo.nombre}</option>
			{/each}
		</select>
	</div>

	<div class="mt-3">
		<label for="prioridad" class="block text-sm font-medium mb-1">Prioridad</label>
		<select id="prioridad" bind:value={prioridad} class="w-full px-3 py-2 border border-border rounded-md text-sm">
			<option value="baja">Baja</option>
			<option value="media" selected>Media</option>
			<option value="alta">Alta</option>
			<option value="critica">Crítica</option>
		</select>
	</div>

	<div class="mt-3">
		<label for="titulo" class="block text-sm font-medium mb-1">Título *</label>
		<input id="titulo" bind:value={titulo} required placeholder="Resumen breve del problema" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	<div class="mt-3">
		<label for="descripcion" class="block text-sm font-medium mb-1">Descripción *</label>
		<textarea id="descripcion" bind:value={descripcion} rows="4" required placeholder="Detalle del reclamo..." class="w-full px-3 py-2 border border-border rounded-md text-sm"></textarea>
	</div>

	<!-- Asignación de inspección (solo si es vecino o no se resolvió automáticamente) -->
	{#if !esReganteSeleccionado}
		<div class="mt-3">
			<label for="inspeccion" class="block text-sm font-medium mb-1">Inspección de destino *</label>
			<select id="inspeccion" bind:value={inspeccion_id} required class="w-full px-3 py-2 border border-border rounded-md text-sm">
				<option value={undefined} disabled selected>Seleccionar inspección...</option>
				{#each data.inspecciones as insp}
					<option value={insp.id}>{insp.nombre}</option>
				{/each}
			</select>
		</div>
	{/if}

	<!-- Ubicación: solo requerida cuando NO hay toma/ccpp resuelto -->
	{#if !esReganteSeleccionado}
		<fieldset class="border border-border rounded-lg p-4 mt-4">
			<legend class="font-semibold px-2">Ubicación</legend>

			{#if latitud && longitud}
				<p class="text-primary text-sm my-2">
					Ubicación obtenida: {latitud.toFixed(5)}, {longitud.toFixed(5)}
				</p>
			{/if}

			<div class="flex gap-3 mb-3">
				<button type="button" on:click={usarMiUbicacion} class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark">Usar mi ubicación</button>
			</div>

			<label for="direccion" class="block text-sm font-medium mb-1">Dirección manual</label>
			<input id="direccion" bind:value={direccion_manual} placeholder="Ej: Av. San Martín 1234, Godoy Cruz" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
		</fieldset>
	{/if}

	{#if error}
		<div class="bg-danger-bg border border-danger-border text-danger px-4 py-3 rounded-md text-sm mt-3" role="alert">{error}</div>
	{/if}

	<div class="mt-6 flex gap-3">
		<button type="submit" disabled={enviando} class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark disabled:opacity-50">
			{enviando ? 'Creando...' : 'Crear reclamo'}
		</button>
		<a href="/reclamos" class="px-4 py-2 text-text no-underline text-sm border border-border rounded-md hover:bg-bg">Cancelar</a>
	</div>
</form>
