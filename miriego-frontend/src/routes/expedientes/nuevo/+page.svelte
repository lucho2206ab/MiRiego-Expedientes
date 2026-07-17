<script lang="ts">
	import type { PageData } from './$types';
	import { goto } from '$app/navigation';
	import { crearExpediente } from '$lib/api/expedientes';

	export let data: PageData;

	const r = data.reclamante;
	const nombreCompleto = [r.nombre, r.apellido].filter(Boolean).join(' ').trim();

	let numero_expediente = '';
	let tipo_id: number | undefined;
	let asunto = '';
	let descripcion = '';
	let iniciador_nombre = nombreCompleto;
	let iniciador_dni_cuit = r.dni;
	let iniciador_cc = r.cc;
	let iniciador_pp = r.pp;
	let iniciador_email = '';
	let iniciador_telefono = '';
	let sector_actual_id: number | undefined;
	let sector_opcion: number | 'otro' | '' = '';
	let sector_nombre_manual = '';
	let inspeccion_id: number | undefined;
	let fecha_inicio = '';
	let fecha_vencimiento = '';
	let es_expediente_electronico = false;
	let gde_numero = '';
	let es_expediente_acumulado = false;
	let expediente_acumulado_numero = '';

	let enviando = false;
	let error = '';

	async function onSubmit() {
		if (!tipo_id) {
			error = 'Completá tipo de expediente.';
			return;
		}
		if (!sector_opcion) {
			error = 'Seleccioná un sector inicial.';
			return;
		}
		if (sector_opcion === 'otro' && !sector_nombre_manual.trim()) {
			error = 'Ingresá el nombre del sector.';
			return;
		}

		enviando = true;
		error = '';

		try {
			const payload: Record<string, unknown> = {
				numero_expediente: numero_expediente.toUpperCase(),
				tipo_id,
				asunto: asunto.toUpperCase(),
				descripcion: descripcion ? descripcion.toUpperCase() : undefined,
				iniciador_nombre: iniciador_nombre.toUpperCase(),
				iniciador_dni_cuit: iniciador_dni_cuit ? iniciador_dni_cuit.toUpperCase() : undefined,
				iniciador_cc: iniciador_cc ? iniciador_cc.toUpperCase() : undefined,
				iniciador_pp: iniciador_pp ? iniciador_pp.toUpperCase() : undefined,
				iniciador_email: iniciador_email ? iniciador_email.toLowerCase() : undefined,
				iniciador_telefono: iniciador_telefono ? iniciador_telefono : undefined,
				inspeccion_id: inspeccion_id || undefined,
				fecha_inicio: fecha_inicio ? fecha_inicio + 'T00:00:00-03:00' : undefined,
				fecha_vencimiento: fecha_vencimiento ? fecha_vencimiento + 'T00:00:00-03:00' : undefined,
				reclamo_id: data.reclamo_id
			};

			if (sector_opcion === 'otro') {
				payload.sector_nombre = sector_nombre_manual.toUpperCase();
			} else if (typeof sector_opcion === 'number') {
				payload.sector_actual_id = sector_opcion;
			}

			if (es_expediente_electronico && gde_numero.trim()) {
				payload.gde_numero = gde_numero.toUpperCase();
			}

			if (es_expediente_acumulado && expediente_acumulado_numero.trim()) {
				payload.expediente_acumulado_numero = expediente_acumulado_numero.toUpperCase();
			}

			const nuevo = await crearExpediente(payload as any);
			await goto(`/expedientes/${nuevo.id}`);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Error al crear el expediente';
		} finally {
			enviando = false;
		}
	}
</script>

<h1 class="text-2xl font-bold mb-4">Nuevo expediente</h1>

<form on:submit|preventDefault={onSubmit} class="space-y-4">
	<div>
		<label for="numero" class="block text-sm font-medium mb-1">Número de expediente</label>
		<input id="numero" bind:value={numero_expediente} required placeholder="EXP-2026-000045" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
		<label class="flex items-center gap-2 mt-2 text-sm">
			<input type="checkbox" bind:checked={es_expediente_electronico} /> Asignado a Expediente electrónico
		</label>
		{#if es_expediente_electronico}
			<input id="gde-numero" bind:value={gde_numero} placeholder="Número de expediente GDE" class="w-full px-3 py-2 border border-border rounded-md text-sm mt-2" />
		{/if}
		<label class="flex items-center gap-2 mt-2 text-sm">
			<input type="checkbox" bind:checked={es_expediente_acumulado} /> Expediente Acumulado
		</label>
		{#if es_expediente_acumulado}
			<input id="expediente-acumulado" bind:value={expediente_acumulado_numero} placeholder="Número de expediente acumulado" class="w-full px-3 py-2 border border-border rounded-md text-sm mt-2" />
		{/if}
	</div>

	<div>
		<label for="inspeccion" class="block text-sm font-medium mb-1">Inspección (opcional)</label>
		<select id="inspeccion" bind:value={inspeccion_id} class="w-full px-3 py-2 border border-border rounded-md text-sm">
			<option value={undefined} selected>Sin inspección</option>
			{#each data.inspecciones as inspeccion}
				<option value={inspeccion.id}>{inspeccion.nombre}</option>
			{/each}
		</select>
	</div>

	<div>
		<label for="tipo" class="block text-sm font-medium mb-1">Tipo de expediente</label>
		<select id="tipo" bind:value={tipo_id} required class="w-full px-3 py-2 border border-border rounded-md text-sm">
			<option value={undefined} disabled selected>Seleccionar...</option>
			{#each data.tipos as tipo}
				<option value={tipo.id}>{tipo.nombre}</option>
			{/each}
		</select>
	</div>

	<div>
		<label for="asunto" class="block text-sm font-medium mb-1">Asunto</label>
		<input id="asunto" bind:value={asunto} required class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	<div>
		<label for="descripcion" class="block text-sm font-medium mb-1">Descripción</label>
		<textarea id="descripcion" bind:value={descripcion} rows="4" class="w-full px-3 py-2 border border-border rounded-md text-sm"></textarea>
	</div>

	<div>
		<label for="iniciador" class="block text-sm font-medium mb-1">Nombre del iniciador</label>
		<input id="iniciador" bind:value={iniciador_nombre} required class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	<div>
		<label for="dni" class="block text-sm font-medium mb-1">DNI / CUIT del iniciador (opcional)</label>
		<input id="dni" bind:value={iniciador_dni_cuit} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	<div>
		<label for="cc" class="block text-sm font-medium mb-1">CC del iniciador (opcional)</label>
		<input id="cc" bind:value={iniciador_cc} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	<div>
		<label for="pp" class="block text-sm font-medium mb-1">PP del iniciador (opcional)</label>
		<input id="pp" bind:value={iniciador_pp} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	<div>
		<label for="email" class="block text-sm font-medium mb-1">Email del iniciador (opcional)</label>
		<input id="email" type="email" bind:value={iniciador_email} placeholder="correo@ejemplo.com" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	<div>
		<label for="telefono" class="block text-sm font-medium mb-1">Teléfono del iniciador (opcional)</label>
		<input id="telefono" bind:value={iniciador_telefono} placeholder="261-XXX-XXXX" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	<div>
		<label for="sector" class="block text-sm font-medium mb-1">Sector inicial</label>
		<select id="sector" bind:value={sector_opcion} required class="w-full px-3 py-2 border border-border rounded-md text-sm">
			<option value="" disabled selected>Seleccionar...</option>
			{#each data.sectores as sector}
				<option value={sector.id}>{sector.nombre}</option>
			{/each}
			<option value="otro">Otro...</option>
		</select>
	</div>

	{#if sector_opcion === 'otro'}
		<div>
			<label for="sector-manual" class="block text-sm font-medium mb-1">Nombre del sector</label>
			<input id="sector-manual" bind:value={sector_nombre_manual} required placeholder="Ingresar nombre del sector..." class="w-full px-3 py-2 border border-border rounded-md text-sm" style="text-transform: uppercase;" />
		</div>
	{/if}

	<div>
		<label for="fecha-inicio" class="block text-sm font-medium mb-1">Fecha de inicio</label>
		<input id="fecha-inicio" type="date" bind:value={fecha_inicio} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	<div>
		<label for="vencimiento" class="block text-sm font-medium mb-1">Fecha de vencimiento (opcional)</label>
		<input id="vencimiento" type="date" bind:value={fecha_vencimiento} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	{#if error}
		<p class="text-danger text-sm">{error}</p>
	{/if}

	<div class="pt-4">
		<button type="submit" disabled={enviando} class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark disabled:opacity-50">
			{enviando ? 'Creando...' : 'Crear expediente'}
		</button>
	</div>
</form>
