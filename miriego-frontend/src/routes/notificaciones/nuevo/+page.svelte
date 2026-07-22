<script lang="ts">
	import type { PageData } from './$types';
	import { goto } from '$app/navigation';
	import { crearNotificacion } from '$lib/api/notificaciones';
	import type { NotificacionCreatePayload } from '$lib/types/notificacion';

	export let data: PageData;

	// Notificado
	let notificadoTipo: NotificadoTipo = 'tercero';
	let cc = '';
	let pp = '';
	let notificadoNombre = '';
	let notificadoDocumento = '';
	let notificadoDomicilio = '';
	let notificadoContacto = '';

	// Clasificación
	let tipoNotificacionId: number | undefined;
	let medioNotificacionId: number | undefined;

	// Contenido
	let motivo = '';
	let descripcion = '';

	// Fechas
	let fechaVencimiento = '';

	// Observaciones
	let observaciones = '';

	let enviando = false;
	let error = '';

	type NotificadoTipo = 'regante' | 'tercero';

	async function onSubmit() {
		if (!motivo.trim()) {
			error = 'Completá el motivo.';
			return;
		}
		if (!descripcion.trim()) {
			error = 'Completá la descripción.';
			return;
		}

		enviando = true;
		error = '';

		try {
			const payload: NotificacionCreatePayload = {
				notificado_tipo: notificadoTipo,
				cc: cc ? cc.toUpperCase() : undefined,
				pp: pp ? pp.toUpperCase() : undefined,
				notificado_nombre: notificadoNombre ? notificadoNombre.toUpperCase() : undefined,
				notificado_documento: notificadoDocumento || undefined,
				notificado_domicilio: notificadoDomicilio ? notificadoDomicilio.toUpperCase() : undefined,
				notificado_contacto: notificadoContacto || undefined,
				tipo_notificacion_id: tipoNotificacionId ?? null,
				medio_notificacion_id: medioNotificacionId ?? null,
				motivo: motivo.toUpperCase(),
				descripcion: descripcion.toUpperCase(),
				fecha_vencimiento_respuesta: fechaVencimiento || undefined,
				observaciones: observaciones ? observaciones.toUpperCase() : undefined
			};

			const nueva = await crearNotificacion(payload);
			await goto(`/notificaciones/${nueva.id}`);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Error al crear la notificación';
		} finally {
			enviando = false;
		}
	}
</script>

<h1 class="text-2xl font-bold mb-2">Nueva notificación</h1>
<p class="text-sm text-text-muted mb-4">Versión preliminar — el formulario definitivo se adaptará por tipo de notificación.</p>

<form on:submit|preventDefault={onSubmit}>
	<!-- Notificado -->
	<fieldset class="border border-border rounded-lg p-4 mt-4">
		<legend class="font-semibold px-2">¿A quién se notifica?</legend>

		<div class="flex gap-6 mt-1">
			<label class="flex items-center gap-2 text-sm cursor-pointer">
				<input type="radio" name="notificado-tipo" value="regante" bind:group={notificadoTipo} /> Regante
			</label>
			<label class="flex items-center gap-2 text-sm cursor-pointer">
				<input type="radio" name="notificado-tipo" value="tercero" bind:group={notificadoTipo} /> Tercero
			</label>
		</div>

		{#if notificadoTipo === 'regante'}
			<div class="grid grid-cols-2 gap-3 mt-4">
				<div>
					<label for="n-cc" class="block text-sm font-medium mb-1">CC (Código de Cauce)</label>
					<input id="n-cc" bind:value={cc} placeholder="Ej: CC-001" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
				<div>
					<label for="n-pp" class="block text-sm font-medium mb-1">PP (Padrón Parcial)</label>
					<input id="n-pp" bind:value={pp} placeholder="Ej: PP-001" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
				</div>
			</div>
		{/if}

		<div class="grid grid-cols-2 gap-3 mt-4">
			<div>
				<label for="n-nombre" class="block text-sm font-medium mb-1">Nombre / Razón Social</label>
				<input id="n-nombre" bind:value={notificadoNombre} placeholder="Nombre completo o razón social" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="n-documento" class="block text-sm font-medium mb-1">Documento (DNI/CUIT)</label>
				<input id="n-documento" bind:value={notificadoDocumento} placeholder="DNI, CUIT o CUIL" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div class="col-span-2">
				<label for="n-domicilio" class="block text-sm font-medium mb-1">Domicilio</label>
				<input id="n-domicilio" bind:value={notificadoDomicilio} placeholder="Dirección completa" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div class="col-span-2">
				<label for="n-contacto" class="block text-sm font-medium mb-1">Contacto (teléfono/email)</label>
				<input id="n-contacto" bind:value={notificadoContacto} placeholder="Opcional" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
		</div>
	</fieldset>

	<!-- Clasificación -->
	<div class="grid grid-cols-2 gap-3 mt-4">
		<div>
			<label for="n-tipo-notif" class="block text-sm font-medium mb-1">Tipo de notificación</label>
			<select id="n-tipo-notif" bind:value={tipoNotificacionId} class="w-full px-3 py-2 border border-border rounded-md text-sm">
				<option value={undefined}>Seleccionar...</option>
				{#each data.tiposNotificacion as tipo}
					<option value={tipo.id}>{tipo.nombre}</option>
				{/each}
			</select>
		</div>
		<div>
			<label for="n-medio" class="block text-sm font-medium mb-1">Medio de notificación</label>
			<select id="n-medio" bind:value={medioNotificacionId} class="w-full px-3 py-2 border border-border rounded-md text-sm">
				<option value={undefined}>Seleccionar...</option>
				{#each data.mediosNotificacion as medio}
					<option value={medio.id}>{medio.nombre}</option>
				{/each}
			</select>
		</div>
	</div>

	<!-- Contenido -->
	<div class="mt-4">
		<label for="n-motivo" class="block text-sm font-medium mb-1">Motivo *</label>
		<input id="n-motivo" bind:value={motivo} required placeholder="Resumen breve del motivo" class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	<div class="mt-3">
		<label for="n-descripcion" class="block text-sm font-medium mb-1">Descripción *</label>
		<textarea id="n-descripcion" bind:value={descripcion} rows="4" required placeholder="Detalle de la notificación..." class="w-full px-3 py-2 border border-border rounded-md text-sm"></textarea>
	</div>

	<!-- Fechas -->
	<div class="mt-3">
		<label for="n-vencimiento" class="block text-sm font-medium mb-1">Fecha vencimiento de respuesta</label>
		<input id="n-vencimiento" type="date" bind:value={fechaVencimiento} class="px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	<!-- Observaciones -->
	<div class="mt-3">
		<label for="n-obs" class="block text-sm font-medium mb-1">Observaciones</label>
		<textarea id="n-obs" bind:value={observaciones} rows="2" placeholder="Notas internas (opcional)" class="w-full px-3 py-2 border border-border rounded-md text-sm"></textarea>
	</div>

	{#if error}
		<div class="bg-danger-bg border border-danger-border text-danger px-4 py-3 rounded-md text-sm mt-3" role="alert">{error}</div>
	{/if}

	<div class="mt-6 flex gap-3">
		<button type="submit" disabled={enviando} class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark disabled:opacity-50">
			{enviando ? 'Creando...' : 'Crear notificación'}
		</button>
		<a href="/notificaciones" class="px-4 py-2 text-text no-underline text-sm border border-border rounded-md hover:bg-bg">Cancelar</a>
	</div>
</form>
