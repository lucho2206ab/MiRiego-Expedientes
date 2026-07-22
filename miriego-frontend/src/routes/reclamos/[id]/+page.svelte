<script lang="ts">
	import type { PageData } from './$types';
	import { invalidateAll } from '$app/navigation';
	import { actualizarReclamo, agregarComentario } from '$lib/api/reclamos';
	import { generarPdfReclamo } from '$lib/utils/pdf';

	export let data: PageData;

	$: reclamo = data.reclamo;
	$: esBloqueado = reclamo.estado === 'derivado_expediente';

	function nombreCanal(canalId: number | null | undefined): string {
		if (!canalId) return '—';
		return data.canales.find((c) => c.id === canalId)?.nombre ?? `Canal ${canalId}`;
	}

	function nombreToma(tomaId: number | null | undefined): string {
		if (!tomaId) return '—';
		const t = data.tomas.find((t) => t.id === tomaId);
		return t?.codigo_toma ?? `Toma ${tomaId}`;
	}

	function nombreInspeccion(inspeccionId: number | null | undefined): string {
		if (!inspeccionId) return '—';
		return data.inspecciones.find((i) => i.id === inspeccionId)?.nombre ?? `Inspección ${inspeccionId}`;
	}

	function nombreTipo(tipoId: number): string {
		return data.tipos.find((t) => t.id === tipoId)?.nombre ?? `Tipo ${tipoId}`;
	}

	function colorPrioridad(p: string): string {
		switch (p) {
			case 'critica': return 'crimson';
			case 'alta': return '#e67700';
			case 'media': return 'var(--color-primary)';
			case 'baja': return '#888';
			default: return 'inherit';
		}
	}

	function formatoFecha(iso: string | null | undefined): string {
		if (!iso) return '—';
		return new Date(iso).toLocaleString('es-AR');
	}

	// --- Cambio de estado ---
	let nuevoEstado = '';
	let enviandoEstado = false;
	let expedienteVinculado = '';
	let comentarioEstado = '';
	let sectorAsignado: number | '' = '';

	async function onCambiarEstado() {
		if (!nuevoEstado) return;
		enviandoEstado = true;
		try {
			const payload: { estado: string; expediente_id?: number | null; comentario?: string; sector_actual_id?: number } = { estado: nuevoEstado };
			if (nuevoEstado === 'derivado_expediente' && expedienteVinculado.trim()) {
				const expId = parseInt(expedienteVinculado.trim().toUpperCase(), 10);
				if (!isNaN(expId)) payload.expediente_id = expId;
			}
			if (comentarioEstado.trim()) {
				payload.comentario = comentarioEstado.toUpperCase();
			}
			if (nuevoEstado === 'asignado' && sectorAsignado !== '') {
				payload.sector_actual_id = Number(sectorAsignado);
			}
			await actualizarReclamo(reclamo.id, payload);
			nuevoEstado = '';
			expedienteVinculado = '';
			comentarioEstado = '';
			sectorAsignado = '';
			await invalidateAll();
		} finally {
			enviandoEstado = false;
		}
	}

	// --- Comentario ---
	let contenidoComentario = '';
	let esInterno = false;
	let enviandoComentario = false;

	async function onAgregarComentario() {
		if (!contenidoComentario.trim()) return;
		enviandoComentario = true;
		try {
			await agregarComentario(reclamo.id, {
				comentario: contenidoComentario.toUpperCase(),
				es_interno: esInterno
			});
			contenidoComentario = '';
			esInterno = false;
			await invalidateAll();
		} finally {
			enviandoComentario = false;
		}
	}

	// --- Modo edicion ---
	let editando = false;
	let editTitulo = '';
	let editDescripcion = '';
	let editReclamanteNombre = '';
	let editReclamanteApellido = '';
	let editReclamanteDni = '';
	let editReclamanteTelefono = '';
	let editReclamanteEmail = '';
	let editReclamanteCc = '';
	let editReclamantePp = '';
	let editDireccion = '';
	let guardandoEdicion = false;
	let errorEdicion = '';

	function entrarEdicion() {
		editTitulo = reclamo.titulo;
		editDescripcion = reclamo.descripcion;
		editReclamanteNombre = reclamo.reclamante_nombre ?? '';
		editReclamanteApellido = reclamo.reclamante_apellido ?? '';
		editReclamanteDni = reclamo.reclamante_dni ?? '';
		editReclamanteTelefono = reclamo.reclamante_telefono ?? '';
		editReclamanteEmail = reclamo.reclamante_email ?? '';
		editReclamanteCc = reclamo.reclamante_cc ?? '';
		editReclamantePp = reclamo.reclamante_pp ?? '';
		editDireccion = reclamo.direccion_manual ?? '';
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
			await actualizarReclamo(reclamo.id, {
				titulo: editTitulo.toUpperCase(),
				descripcion: editDescripcion.toUpperCase(),
				reclamante_nombre: editReclamanteNombre ? editReclamanteNombre.toUpperCase() : undefined,
				reclamante_apellido: editReclamanteApellido ? editReclamanteApellido.toUpperCase() : undefined,
				reclamante_dni: editReclamanteDni || undefined,
				reclamante_telefono: editReclamanteTelefono || undefined,
				reclamante_email: editReclamanteEmail || undefined,
				reclamante_cc: editReclamanteCc ? editReclamanteCc.toUpperCase() : undefined,
				reclamante_pp: editReclamantePp ? editReclamantePp.toUpperCase() : undefined,
				direccion_manual: editDireccion ? editDireccion.toUpperCase() : undefined
			});
			editando = false;
			await invalidateAll();
		} catch (e) {
			errorEdicion = e instanceof Error ? e.message : 'Error al guardar';
		} finally {
			guardandoEdicion = false;
		}
	}

	// Todos los estados disponibles para cambio
	const estadosDisponibles: { valor: string; label: string }[] = [
		{ valor: 'recibido', label: 'Recibido' },
		{ valor: 'en_revision', label: 'En revisión' },
		{ valor: 'asignado', label: 'Asignado' },
		{ valor: 'en_proceso', label: 'En proceso' },
		{ valor: 'resuelto', label: 'Resuelto' },
		{ valor: 'cerrado', label: 'Cerrado' },
		{ valor: 'rechazado', label: 'Rechazado' },
		{ valor: 'derivado', label: 'Derivado' },
		{ valor: 'derivado_expediente', label: 'Derivado a expediente' },
		{ valor: 'pendiente_informacion', label: 'Pendiente info' },
		{ valor: 'cancelado', label: 'Cancelado' },
		{ valor: 'reabierto', label: 'Reabierto' },
	];

	// --- PDF ---
	function onDescargarPdf() {
		generarPdfReclamo(reclamo, nombreCanal, nombreToma, nombreInspeccion, nombreTipo);
	}
</script>

<a href="/reclamos" class="text-primary hover:underline text-sm">&larr; Volver al listado</a>

<h1 class="text-2xl font-bold mt-2 mb-1">{reclamo.codigo_reclamo}</h1>

<div class="flex gap-2 mb-3">
	{#if !editando && !esBloqueado}
		<button on:click={entrarEdicion} class="bg-white border border-border text-sm px-3 py-1.5 rounded-md cursor-pointer hover:bg-bg">Editar datos</button>
	{/if}
	<button on:click={onDescargarPdf} class="bg-white border border-border text-sm px-3 py-1.5 rounded-md cursor-pointer hover:bg-bg">Descargar PDF</button>
</div>

{#if editando}
	<form on:submit|preventDefault={guardarEdicion} class="space-y-3 mb-6 bg-bg p-4 rounded-lg border border-border">
		<div class="grid grid-cols-1 md:grid-cols-2 gap-3">
			<div class="md:col-span-2">
				<label for="edit-titulo" class="block text-sm font-medium mb-1">Titulo</label>
				<input id="edit-titulo" bind:value={editTitulo} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div class="md:col-span-2">
				<label for="edit-descripcion" class="block text-sm font-medium mb-1">Descripcion</label>
				<textarea id="edit-descripcion" bind:value={editDescripcion} rows="2" class="w-full px-3 py-2 border border-border rounded-md text-sm"></textarea>
			</div>
			<div>
				<label for="edit-nombre" class="block text-sm font-medium mb-1">Nombre reclamante</label>
				<input id="edit-nombre" bind:value={editReclamanteNombre} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-apellido" class="block text-sm font-medium mb-1">Apellido reclamante</label>
				<input id="edit-apellido" bind:value={editReclamanteApellido} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-dni" class="block text-sm font-medium mb-1">DNI</label>
				<input id="edit-dni" bind:value={editReclamanteDni} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-telefono" class="block text-sm font-medium mb-1">Telefono</label>
				<input id="edit-telefono" bind:value={editReclamanteTelefono} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-email" class="block text-sm font-medium mb-1">Email</label>
				<input id="edit-email" type="email" bind:value={editReclamanteEmail} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-cc" class="block text-sm font-medium mb-1">CC</label>
				<input id="edit-cc" bind:value={editReclamanteCc} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-pp" class="block text-sm font-medium mb-1">PP</label>
				<input id="edit-pp" bind:value={editReclamantePp} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
			</div>
			<div>
				<label for="edit-direccion" class="block text-sm font-medium mb-1">Direccion</label>
				<input id="edit-direccion" bind:value={editDireccion} class="w-full px-3 py-2 border border-border rounded-md text-sm" />
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
	<p class="font-semibold mb-1">{reclamo.titulo}</p>
	<p class="mb-3 text-text-muted">{reclamo.descripcion}</p>
{/if}

<p class="mb-3">
	Tipo: <strong>{nombreTipo(reclamo.tipo_id)}</strong>
	<span class="mx-2 text-text-muted">|</span>
	Prioridad: <span style="color: {colorPrioridad(reclamo.prioridad)}" class="font-semibold">{reclamo.prioridad}</span>
	<span class="mx-2 text-text-muted">|</span>
	Estado: <span class="inline-block px-2 py-0.5 rounded-full text-xs {['cerrado','rechazado','cancelado','derivado_expediente'].includes(reclamo.estado) ? 'bg-red-100 text-red-700' : 'bg-[#eef2ee] text-primary'}">{reclamo.estado}</span>
</p>

{#if esBloqueado}
	<div class="bg-warning-bg border border-warning-border p-3 rounded mb-4 text-sm">
		<strong>Este reclamo fue derivado a expediente y no admite más cambios.</strong>
		{#if reclamo.expediente_id}
			<br />Expediente vinculado: <a href={`/expedientes/${reclamo.expediente_id}`} class="text-primary hover:underline">{reclamo.numero_expediente ?? reclamo.expediente_id}</a>
		{/if}
	</div>
{:else if reclamo.expediente_id}
	<p class="mb-3">Expediente vinculado: <a href={`/expedientes/${reclamo.expediente_id}`} class="text-primary hover:underline">{reclamo.numero_expediente ?? reclamo.expediente_id}</a></p>
{:else}
	<p class="mb-3"><a href={`/expedientes/nuevo?reclamante_nombre=${encodeURIComponent(reclamo.reclamante_nombre ?? '')}&reclamante_apellido=${encodeURIComponent(reclamo.reclamante_apellido ?? '')}&reclamante_dni=${encodeURIComponent(reclamo.reclamante_dni ?? '')}&reclamante_cc=${encodeURIComponent(reclamo.reclamante_cc ?? '')}&reclamante_pp=${encodeURIComponent(reclamo.reclamante_pp ?? '')}&reclamo_id=${reclamo.id}`} class="text-primary hover:underline">Crear expediente para este reclamo</a></p>
{/if}

<p class="mb-3">
	Canal: {nombreCanal(reclamo.canal_id)}
	<span class="mx-2 text-text-muted">|</span>
	Toma: {nombreToma(reclamo.toma_id)}
	<span class="mx-2 text-text-muted">|</span>
	Inspección: {nombreInspeccion(reclamo.inspeccion_id)}
</p>

{#if reclamo.direccion_manual}
	<p class="mb-1">Dirección: {reclamo.direccion_manual}</p>
{/if}
{#if reclamo.latitud && reclamo.longitud}
	<p class="mb-2">Coordenadas: {reclamo.latitud}, {reclamo.longitud}</p>
{/if}

{#if !editando && (reclamo.reclamante_nombre || reclamo.reclamante_apellido || reclamo.reclamante_cc || reclamo.reclamante_pp || reclamo.reclamante_dni)}
	<h2 class="text-lg font-semibold mt-6 mb-3">Datos del reclamante</h2>
	<div class="overflow-x-auto mb-4">
		<table class="w-full border-collapse text-sm">
			<tbody>
				{#if reclamo.reclamante_nombre || reclamo.reclamante_apellido}
					<tr class="border-b border-border">
						<th class="py-2.5 px-2 text-left font-semibold w-32">Nombre</th>
						<td class="py-2.5 px-2">{reclamo.reclamante_nombre ?? ''} {reclamo.reclamante_apellido ?? ''}</td>
					</tr>
				{/if}
				{#if reclamo.reclamante_cc}
					<tr class="border-b border-border">
						<th class="py-2.5 px-2 text-left font-semibold w-32">CC</th>
						<td class="py-2.5 px-2">{reclamo.reclamante_cc}</td>
					</tr>
				{/if}
				{#if reclamo.reclamante_pp}
					<tr class="border-b border-border">
						<th class="py-2.5 px-2 text-left font-semibold w-32">PP</th>
						<td class="py-2.5 px-2">{reclamo.reclamante_pp}</td>
					</tr>
				{/if}
				{#if reclamo.reclamante_dni}
					<tr class="border-b border-border">
						<th class="py-2.5 px-2 text-left font-semibold w-32">DNI</th>
						<td class="py-2.5 px-2">{reclamo.reclamante_dni}</td>
					</tr>
				{/if}
				{#if reclamo.reclamante_telefono}
					<tr class="border-b border-border">
						<th class="py-2.5 px-2 text-left font-semibold w-32">Teléfono</th>
						<td class="py-2.5 px-2">{reclamo.reclamante_telefono}</td>
					</tr>
				{/if}
				{#if reclamo.reclamante_email}
					<tr class="border-b border-border">
						<th class="py-2.5 px-2 text-left font-semibold w-32">Email</th>
						<td class="py-2.5 px-2">{reclamo.reclamante_email}</td>
					</tr>
				{/if}
			</tbody>
		</table>
	</div>
{/if}

<p class="text-text-muted text-sm mb-6">
	Creado: {formatoFecha(reclamo.fecha_creacion)}
	{#if reclamo.fecha_primera_respuesta}
		<span class="mx-1">|</span> Primera respuesta: {formatoFecha(reclamo.fecha_primera_respuesta)}
	{/if}
	{#if reclamo.fecha_resolucion}
		<span class="mx-1">|</span> Resuelto: {formatoFecha(reclamo.fecha_resolucion)}
	{/if}
	{#if reclamo.fecha_cierre}
		<span class="mx-1">|</span> Cerrado: {formatoFecha(reclamo.fecha_cierre)}
	{/if}
</p>

{#if !esBloqueado}
<hr class="border-border my-6" />

<!-- Cambio de estado -->
<h2 class="text-lg font-semibold mb-3">Cambiar estado</h2>
<form on:submit|preventDefault={onCambiarEstado} class="space-y-3 mb-6">
	<div class="flex gap-3 items-end flex-wrap">
		<div>
			<label for="nuevo-estado" class="block text-sm font-medium mb-1">Nuevo estado</label>
			<select id="nuevo-estado" bind:value={nuevoEstado} class="px-3 py-2 border border-border rounded-md text-sm">
				<option value="">Seleccionar...</option>
				{#each estadosDisponibles as est}
					{#if est.valor !== reclamo.estado}
						<option value={est.valor}>{est.label}</option>
					{/if}
				{/each}
			</select>
		</div>
		{#if nuevoEstado === 'derivado_expediente'}
			<div>
				<label for="expediente-vinculado" class="block text-sm font-medium mb-1">N° Expediente</label>
				<input id="expediente-vinculado" bind:value={expedienteVinculado} placeholder="Ej: EXP-2026-000045" class="px-3 py-2 border border-border rounded-md text-sm" />
			</div>
		{/if}
		{#if nuevoEstado === 'asignado'}
			<div>
				<label for="sector-asignado" class="block text-sm font-medium mb-1">Sector</label>
				<select id="sector-asignado" bind:value={sectorAsignado} class="px-3 py-2 border border-border rounded-md text-sm">
					<option value="">Seleccionar sector...</option>
					{#each data.sectores as sector}
						<option value={sector.id}>{sector.nombre}</option>
					{/each}
				</select>
			</div>
		{/if}
	</div>
	{#if nuevoEstado}
		<div>
			<label for="comentario-estado" class="block text-sm font-medium mb-1">Comentario (opcional)</label>
			<textarea id="comentario-estado" bind:value={comentarioEstado} rows="2" placeholder="Agregar comentario sobre el cambio de estado..." class="w-full px-3 py-2 border border-border rounded-md text-sm"></textarea>
		</div>
	{/if}
	<button type="submit" disabled={enviandoEstado || !nuevoEstado} class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark disabled:opacity-50">
		{enviandoEstado ? 'Actualizando...' : 'Cambiar estado'}
	</button>
</form>
{/if}

<hr class="border-border my-6" />

<!-- Historial -->
<h2 class="text-lg font-semibold mb-3">Historial</h2>
{#if reclamo.historial.length === 0}
	<p class="text-text-muted">Sin movimientos.</p>
{:else}
	<ul class="space-y-2">
		{#each reclamo.historial as h}
			<li class="border-b border-border pb-2">
				<strong>{formatoFecha(h.fecha)}</strong> — {h.accion}
				{#if h.estado_anterior && h.estado_nuevo}
					: <span class="inline-block px-2 py-0.5 rounded-full text-xs {['cerrado','rechazado','cancelado','derivado_expediente'].includes(h.estado_anterior) ? 'bg-red-100 text-red-700' : 'bg-[#eef2ee] text-primary'}">{h.estado_anterior}</span> &rarr; <span class="inline-block px-2 py-0.5 rounded-full text-xs {['cerrado','rechazado','cancelado','derivado_expediente'].includes(h.estado_nuevo) ? 'bg-red-100 text-red-700' : 'bg-[#eef2ee] text-primary'}">{h.estado_nuevo}</span>
				{/if}
				{#if h.observacion}
					<br /><em class="text-text-muted">{h.observacion}</em>
				{/if}
			</li>
		{/each}
	</ul>
{/if}
