<script lang="ts">
	import type { PageData } from './$types';
	import { invalidateAll } from '$app/navigation';
	import {
		generarPase,
		agregarNota,
		actualizarExpediente
	} from '$lib/api/expedientes';
	import type { SubsectorMesaEntradas } from '$lib/types/expediente';
	import { generarPdfExpediente } from '$lib/utils/pdf';

	export let data: PageData;

	$: expediente = data.expediente;

	const SECTOR_INSPECCION_CAUCES = 'Inspección de Cauces';
	const SECTOR_MESA_ENTRADAS = 'Mesa de Entradas';
	const SUBSECTORES_MESA_ENTRADAS: SubsectorMesaEntradas[] = [
		'Casilla de Vencimiento',
		'Notificador',
		'Reserva',
		'Archivo Mesa de Entradas',
		'Archivo Deposito',
		'Recepcion'
	];

	function nombreSector(sectorId: number): string {
		return data.sectores.find((s) => s.id === sectorId)?.nombre ?? `Sector ${sectorId}`;
	}

	function nombreInspeccion(inspeccionId: number): string {
		return data.inspecciones.find((i) => i.id === inspeccionId)?.nombre ?? `Inspección ${inspeccionId}`;
	}

	// --- Modo edicion ---
	let editando = false;
	let editNumero = '';
	let editAsunto = '';
	let editDescripcion = '';
	let editIniciadorNombre = '';
	let editIniciadorDni = '';
	let editIniciadorCc = '';
	let editIniciadorPp = '';
	let editIniciadorEmail = '';
	let editIniciadorTelefono = '';
	let editGdeNumero = '';
	let editInfogovNumero = '';
	let editFechaVencimiento = '';
	let guardandoEdicion = false;
	let errorEdicion = '';

	function entrarEdicion() {
		editNumero = expediente.numero_expediente;
		editAsunto = expediente.asunto;
		editDescripcion = expediente.descripcion ?? '';
		editIniciadorNombre = expediente.iniciador_nombre;
		editIniciadorDni = expediente.iniciador_dni_cuit ?? '';
		editIniciadorCc = expediente.iniciador_cc ?? '';
		editIniciadorPp = expediente.iniciador_pp ?? '';
		editIniciadorEmail = expediente.iniciador_email ?? '';
		editIniciadorTelefono = expediente.iniciador_telefono ?? '';
		editGdeNumero = expediente.gde_numero ?? '';
		editInfogovNumero = expediente.infogov_numero ?? '';
		editFechaVencimiento = expediente.fecha_vencimiento ? expediente.fecha_vencimiento.substring(0, 10) : '';
		editando = true;
		errorEdicion = '';
	}

	function cancelarEdicion() {
		editando = false;
		errorEdicion = '';
	}

	async function guardarEdicion() {
		guardandoEdicion = true;
		errorEdicion = '';
		try {
			await actualizarExpediente(expediente.id, {
				numero_expediente: editNumero.toUpperCase(),
				asunto: editAsunto.toUpperCase(),
				descripcion: editDescripcion ? editDescripcion.toUpperCase() : undefined,
				iniciador_nombre: editIniciadorNombre.toUpperCase(),
				iniciador_dni_cuit: editIniciadorDni || undefined,
				iniciador_cc: editIniciadorCc ? editIniciadorCc.toUpperCase() : undefined,
				iniciador_pp: editIniciadorPp ? editIniciadorPp.toUpperCase() : undefined,
				iniciador_email: editIniciadorEmail || undefined,
				iniciador_telefono: editIniciadorTelefono || undefined,
				gde_numero: editGdeNumero || undefined,
				infogov_numero: editInfogovNumero || undefined,
				fecha_vencimiento: editFechaVencimiento ? editFechaVencimiento + 'T00:00:00-03:00' : undefined
			});
			editando = false;
			await invalidateAll();
		} catch (e) {
			errorEdicion = e instanceof Error ? e.message : 'Error al guardar';
		} finally {
			guardandoEdicion = false;
		}
	}

	// --- Formulario de pase (derivacion) ---
	let sectorDestinoId: number | undefined;
	let sectorDestinoOpcion: number | 'otro' | undefined;
	let sectorNombreManual = '';
	let motivoPase = '';
	let fechaVencimientoPase = '';
	let inspeccionId: number | undefined;
	let subsectorMesaEntradas: SubsectorMesaEntradas | undefined;
	let enviandoPase = false;
	let errorPase = '';

	$: sectorDestinoNombre = data.sectores.find((s) => s.id === sectorDestinoId)?.nombre;
	$: requiereInspeccion = sectorDestinoNombre === SECTOR_INSPECCION_CAUCES;
	$: requiereSubsectorMesa = sectorDestinoNombre === SECTOR_MESA_ENTRADAS;

	function onSectorDestinoChange() {
		if (sectorDestinoOpcion === 'otro') {
			sectorDestinoId = undefined;
		} else {
			sectorDestinoId = sectorDestinoOpcion as number | undefined;
			sectorNombreManual = '';
		}
		inspeccionId = undefined;
		subsectorMesaEntradas = undefined;
	}

	async function onGenerarPase() {
		const esOtroSector = sectorDestinoOpcion === 'otro';
		if (!esOtroSector && !sectorDestinoId) {
			errorPase = 'Elegí un sector destino.';
			return;
		}
		if (esOtroSector && !sectorNombreManual.trim()) {
			errorPase = 'Ingresá el nombre del sector destino.';
			return;
		}
		if (requiereInspeccion && !inspeccionId) {
			errorPase = 'Seleccioná una inspección.';
			return;
		}
		if (requiereSubsectorMesa && !subsectorMesaEntradas) {
			errorPase = 'Seleccioná un subsector.';
			return;
		}
		enviandoPase = true;
		errorPase = '';
		try {
			const payload: Record<string, unknown> = {
				motivo: motivoPase ? motivoPase.toUpperCase() : undefined,
				fecha_vencimiento: fechaVencimientoPase ? fechaVencimientoPase + 'T00:00:00-03:00' : undefined
			};
			if (esOtroSector) {
				payload.sector_nombre = sectorNombreManual.toUpperCase();
			} else {
				payload.sector_destino_id = sectorDestinoId;
				if (requiereInspeccion) payload.inspeccion_id = inspeccionId;
				if (requiereSubsectorMesa) payload.subsector_mesa_entradas = subsectorMesaEntradas;
			}
			await generarPase(expediente.id, payload);
			motivoPase = '';
			fechaVencimientoPase = '';
			sectorDestinoOpcion = undefined;
			sectorDestinoId = undefined;
			sectorNombreManual = '';
			inspeccionId = undefined;
			subsectorMesaEntradas = undefined;
			await invalidateAll();
		} catch (e) {
			errorPase = e instanceof Error ? e.message : 'Error al generar el pase';
		} finally {
			enviandoPase = false;
		}
	}

	// --- Formulario de nota ---
	let contenidoNota = '';
	let enviandoNota = false;

	async function onAgregarNota() {
		if (!contenidoNota.trim()) return;
		enviandoNota = true;
		try {
			await agregarNota(expediente.id, {
				sector_id: expediente.sector_actual_id,
				contenido: contenidoNota.toUpperCase()
			});
			contenidoNota = '';
			await invalidateAll();
		} finally {
			enviandoNota = false;
		}
	}

	// --- PDF ---
	function onDescargarPdf() {
		generarPdfExpediente(expediente, nombreSector, nombreInspeccion);
	}
</script>

<a href="/expedientes" class="text-primary hover:underline text-sm">&larr; Volver al listado</a>

<h1 class="text-2xl font-bold mt-2 mb-1">
	{expediente.numero_expediente}
	{#if expediente.gde_numero}
		<span class="text-base font-normal text-text-muted ml-2">(GDE: {expediente.gde_numero})</span>
	{/if}
</h1>

<div class="flex gap-2 mb-3">
	{#if !editando}
		<button on:click={entrarEdicion} class="bg-white border border-border text-sm px-3 py-1.5 rounded-md cursor-pointer hover:bg-bg">Editar datos</button>
	{/if}
	<button on:click={onDescargarPdf} class="bg-white border border-border text-sm px-3 py-1.5 rounded-md cursor-pointer hover:bg-bg">Descargar PDF</button>
</div>

{#if editando}
	<form on:submit|preventDefault={guardarEdicion} class="space-y-3 mb-6 bg-bg p-4 rounded-lg border border-border">
		<div class="grid grid-cols-1 md:grid-cols-2 gap-3">
			<div>
				<label for="edit-numero" class="block text-sm font-medium mb-1">N° Expediente</label>
				<input id="edit-numero" bind:value={editNumero} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-iniciador" class="block text-sm font-medium mb-1">Iniciador</label>
				<input id="edit-iniciador" bind:value={editIniciadorNombre} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-dni" class="block text-sm font-medium mb-1">DNI/CUIT</label>
				<input id="edit-dni" bind:value={editIniciadorDni} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-cc" class="block text-sm font-medium mb-1">CC</label>
				<input id="edit-cc" bind:value={editIniciadorCc} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-pp" class="block text-sm font-medium mb-1">PP</label>
				<input id="edit-pp" bind:value={editIniciadorPp} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-email" class="block text-sm font-medium mb-1">Email</label>
				<input id="edit-email" type="email" bind:value={editIniciadorEmail} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-telefono" class="block text-sm font-medium mb-1">Teléfono</label>
				<input id="edit-telefono" bind:value={editIniciadorTelefono} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-vencimiento" class="block text-sm font-medium mb-1">Fecha vencimiento</label>
				<input id="edit-vencimiento" type="date" bind:value={editFechaVencimiento} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div class="md:col-span-2">
				<label for="edit-asunto" class="block text-sm font-medium mb-1">Asunto</label>
				<input id="edit-asunto" bind:value={editAsunto} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div class="md:col-span-2">
				<label for="edit-descripcion" class="block text-sm font-medium mb-1">Descripcion</label>
				<textarea id="edit-descripcion" bind:value={editDescripcion} rows="2" class="w-full px-3 py-2 border border-border rounded-md text-sm"></textarea>
			</div>
			<div>
				<label for="edit-gde" class="block text-sm font-medium mb-1">N° GDE</label>
				<input id="edit-gde" bind:value={editGdeNumero} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-infogov" class="block text-sm font-medium mb-1">N° Infogov</label>
				<input id="edit-infogov" bind:value={editInfogovNumero} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
		</div>
		{#if errorEdicion}<div class="bg-danger-bg border border-danger-border text-danger px-4 py-3 rounded-md text-sm" role="alert">{errorEdicion}</div>{/if}
		<div class="flex gap-2">
			<button type="submit" disabled={guardandoEdicion} class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark disabled:opacity-50">
				{guardandoEdicion ? 'Guardando...' : 'Guardar cambios'}
			</button>
			<button type="button" on:click={cancelarEdicion} class="border border-border px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-bg">
				Cancelar
			</button>
		</div>
	</form>
{:else}
	<p class="font-semibold mb-2">{expediente.asunto}</p>
	{#if expediente.descripcion}<p class="mb-2 text-text-muted">{expediente.descripcion}</p>{/if}

	<p class="mb-2">
		Estado: <span class="inline-block px-2 py-0.5 rounded-full text-xs {expediente.estado === 'archivado' ? 'bg-red-100 text-red-700' : 'bg-[#eef2ee] text-primary'}">{expediente.estado}</span>
		<span class="mx-2 text-text-muted">|</span>
		Sector actual: <strong>{nombreSector(expediente.sector_actual_id)}</strong>
	</p>
	<p class="mb-1">Iniciado por: {expediente.iniciador_nombre} el {new Date(expediente.fecha_inicio).toLocaleDateString('es-AR')}</p>
	{#if expediente.iniciador_dni_cuit || expediente.iniciador_cc || expediente.iniciador_pp}
		<p class="mb-2">
			{#if expediente.iniciador_dni_cuit}DNI/CUIT: {expediente.iniciador_dni_cuit}{/if}
			{#if expediente.iniciador_cc}{#if expediente.iniciador_dni_cuit} | {/if}CC: {expediente.iniciador_cc}{/if}
			{#if expediente.iniciador_pp}{#if expediente.iniciador_dni_cuit || expediente.iniciador_cc} | {/if}PP: {expediente.iniciador_pp}{/if}
		</p>
	{/if}
	{#if expediente.iniciador_email || expediente.iniciador_telefono}
		<p class="mb-2">
			{#if expediente.iniciador_email}Email: {expediente.iniciador_email}{/if}
			{#if expediente.iniciador_telefono}{#if expediente.iniciador_email} | {/if}Teléfono: {expediente.iniciador_telefono}{/if}
		</p>
	{/if}
	{#if expediente.fecha_vencimiento}
		<p class="mb-2">Fecha de vencimiento: <strong>{new Date(expediente.fecha_vencimiento).toLocaleDateString('es-AR')}</strong></p>
	{/if}
{/if}

<hr class="border-border my-6" />

<h2 class="text-lg font-semibold mb-3">Derivar a otro sector (pase)</h2>
<form on:submit|preventDefault={onGenerarPase} class="space-y-3 mb-6">
	<div>
		<label for="sector-destino" class="block text-sm font-medium mb-1">Sector destino</label>
		<select
			id="sector-destino"
			bind:value={sectorDestinoOpcion}
			on:change={onSectorDestinoChange}
			class="w-full px-3 py-2 border border-border rounded-md text-sm"
		>
			<option value={undefined} disabled selected>Seleccionar...</option>
			{#each data.sectores.filter((s) => s.id !== expediente.sector_actual_id) as sector}
				<option value={sector.id}>{sector.nombre}</option>
			{/each}
			<option value="otro">Otro...</option>
		</select>
	</div>

	{#if sectorDestinoOpcion === 'otro'}
		<div>
			<label for="sector-manual" class="block text-sm font-medium mb-1">Nombre del sector destino</label>
			<input id="sector-manual" bind:value={sectorNombreManual} placeholder="Ingresar nombre del sector..." class="w-full px-3 py-2 border border-border rounded-md text-sm" style="text-transform: uppercase;" />
		</div>
	{/if}

	{#if requiereInspeccion}
		<div>
			<label for="inspeccion" class="block text-sm font-medium mb-1">Inspección *</label>
			<select id="inspeccion" bind:value={inspeccionId} class="w-full px-3 py-2 border border-border rounded-md text-sm">
				<option value={undefined} disabled selected>Seleccionar inspección...</option>
				{#each data.inspecciones as inspeccion}
					<option value={inspeccion.id}>{inspeccion.nombre}</option>
				{/each}
			</select>
		</div>
	{/if}

	{#if requiereSubsectorMesa}
		<div>
			<label for="subsector-mesa" class="block text-sm font-medium mb-1">Subsector *</label>
			<select id="subsector-mesa" bind:value={subsectorMesaEntradas} class="w-full px-3 py-2 border border-border rounded-md text-sm">
				<option value={undefined} disabled selected>Seleccionar subsector...</option>
				{#each SUBSECTORES_MESA_ENTRADAS as sub}
					<option value={sub}>{sub}</option>
				{/each}
			</select>
		</div>
	{/if}

	<div>
		<label for="motivo" class="block text-sm font-medium mb-1">Motivo (opcional)</label>
		<input id="motivo" bind:value={motivoPase} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	<div>
		<label for="vencimiento-pase" class="block text-sm font-medium mb-1">Fecha de vencimiento del pase (opcional)</label>
		<input id="vencimiento-pase" type="date" bind:value={fechaVencimientoPase} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
	</div>

	{#if errorPase}<div class="bg-danger-bg border border-danger-border text-danger px-4 py-3 rounded-md text-sm" role="alert">{errorPase}</div>{/if}

	<div>
		<button type="submit" disabled={enviandoPase} class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark disabled:opacity-50">
			{enviandoPase ? 'Enviando...' : 'Generar pase'}
		</button>
	</div>
</form>

<h2 class="text-lg font-semibold mb-3">Historial de pases</h2>
{#if expediente.pases.length === 0}
	<p class="text-text-muted">Todavía no se movió de sector.</p>
{:else}
		<div class="overflow-x-auto mb-6">
		<table class="w-full border-collapse text-sm">
			<thead>
				<tr class="border-b border-border text-left">
					<th class="py-2.5 px-2 font-semibold">Origen</th>
					<th class="py-2.5 px-2 font-semibold">Destino</th>
					<th class="py-2.5 px-2 font-semibold">Detalle</th>
					<th class="py-2.5 px-2 font-semibold">Fecha</th>
					<th class="py-2.5 px-2 font-semibold">Vencimiento</th>
					<th class="py-2.5 px-2 font-semibold">Motivo</th>
				</tr>
			</thead>
			<tbody>
				{#each expediente.pases as pase}
					<tr class="border-b border-border">
						<td class="py-2.5 px-2">{nombreSector(pase.sector_origen_id)}</td>
						<td class="py-2.5 px-2">{nombreSector(pase.sector_destino_id)}</td>
						<td class="py-2.5 px-2">
							{#if pase.inspeccion_id}
								{nombreInspeccion(pase.inspeccion_id)}
							{:else if pase.subsector_mesa_entradas}
								{pase.subsector_mesa_entradas}
							{:else}
								—
							{/if}
						</td>
						<td class="py-2.5 px-2">{new Date(pase.fecha_envio).toLocaleString('es-AR')}</td>
						<td class="py-2.5 px-2">{pase.fecha_vencimiento ? new Date(pase.fecha_vencimiento).toLocaleDateString('es-AR') : '—'}</td>
						<td class="py-2.5 px-2">{pase.motivo ?? '—'}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}

<h2 class="text-lg font-semibold mb-3">Notas</h2>
<form on:submit|preventDefault={onAgregarNota} class="mb-4">
	<textarea bind:value={contenidoNota} rows="3" placeholder="Agregar observación..." class="w-full px-3 py-2 border border-border rounded-md text-sm"></textarea>
	<div class="mt-2">
		<button type="submit" disabled={enviandoNota} class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark disabled:opacity-50">
			Agregar nota
		</button>
	</div>
</form>

{#if expediente.notas.length === 0}
	<p class="text-text-muted">Sin notas todavía.</p>
{:else}
	<ul class="space-y-2">
		{#each expediente.notas as nota}
			<li class="border-b border-border pb-2">
				<strong>{new Date(nota.fecha).toLocaleString('es-AR')}</strong>
				({nombreSector(nota.sector_id)}): {nota.contenido}
			</li>
		{/each}
	</ul>
{/if}
