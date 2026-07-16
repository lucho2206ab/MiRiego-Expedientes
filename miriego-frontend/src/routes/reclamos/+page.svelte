<script lang="ts">
	import type { PageData } from './$types';
	import { goto } from '$app/navigation';

	export let data: PageData;

	let filtroEstado = '';
	let filtroCanal = '';
	let filtroTipo = '';
	let filtroPrioridad = '';
	let busqueda = '';
	let fechaDesde = '';
	let fechaHasta = '';

	// Inicializar desde URL params
	import { onMount } from 'svelte';
	onMount(() => {
		const params = new URLSearchParams(window.location.search);
		busqueda = params.get('q') ?? '';
		fechaDesde = params.get('fecha_desde') ?? '';
		fechaHasta = params.get('fecha_hasta') ?? '';
	});

	function aplicarFiltros() {
		const params = new URLSearchParams();
		if (filtroEstado) params.set('estado', filtroEstado);
		if (filtroCanal) params.set('canal_id', filtroCanal);
		if (filtroTipo) params.set('tipo_id', filtroTipo);
		if (filtroPrioridad) params.set('prioridad', filtroPrioridad);
		if (busqueda.trim()) params.set('q', busqueda.trim());
		if (fechaDesde) params.set('fecha_desde', fechaDesde);
		if (fechaHasta) params.set('fecha_hasta', fechaHasta);
		const qs = params.toString();
		goto(`/reclamos${qs ? `?${qs}` : ''}`, { replaceState: true, keepFocus: true });
	}

	function nombreInspeccion(inspeccionId: number | null | undefined): string {
		if (!inspeccionId) return '—';
		return data.inspecciones.find((i) => i.id === inspeccionId)?.nombre ?? `Inspección ${inspeccionId}`;
	}

	function nombreCanal(canalId: number | null | undefined): string {
		if (!canalId) return '—';
		return data.canales.find((c) => c.id === canalId)?.nombre ?? `Canal ${canalId}`;
	}

	function nombreToma(tomaId: number | null | undefined): string {
		if (!tomaId) return '—';
		const t = data.tomas.find((t) => t.id === tomaId);
		return t?.codigo_toma ?? `Toma ${tomaId}`;
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
</script>

<div class="flex justify-between items-center mb-4">
	<h1 class="text-2xl font-bold">Reclamos</h1>
	<a class="bg-primary text-white px-4 py-2 rounded-md no-underline text-sm hover:bg-primary-dark" href="/reclamos/nuevo">+ Nuevo reclamo</a>
</div>

<!-- Filtros + Búsqueda -->
<form on:submit|preventDefault={aplicarFiltros} class="flex gap-3 flex-wrap mb-4">
	<div>
		<label for="f-buscar" class="block text-sm font-medium mb-1">Buscar</label>
		<input id="f-buscar" bind:value={busqueda} placeholder="Código, título, nombre..." class="w-56 px-3 py-2 border border-border rounded-md text-sm" />
	</div>
	<div>
		<label for="f-fecha-desde" class="block text-sm font-medium mb-1">Desde</label>
		<input id="f-fecha-desde" type="date" bind:value={fechaDesde} class="px-3 py-2 border border-border rounded-md text-sm" />
	</div>
	<div>
		<label for="f-fecha-hasta" class="block text-sm font-medium mb-1">Hasta</label>
		<input id="f-fecha-hasta" type="date" bind:value={fechaHasta} class="px-3 py-2 border border-border rounded-md text-sm" />
	</div>
	<div>
		<label for="f-estado" class="block text-sm font-medium mb-1">Estado</label>
		<select id="f-estado" bind:value={filtroEstado} class="px-3 py-2 border border-border rounded-md text-sm">
			<option value="">Todos</option>
			<option value="nuevo">Nuevo</option>
			<option value="recibido">Recibido</option>
			<option value="en_revision">En revisión</option>
			<option value="asignado">Asignado</option>
			<option value="en_proceso">En proceso</option>
			<option value="resuelto">Resuelto</option>
			<option value="cerrado">Cerrado</option>
			<option value="rechazado">Rechazado</option>
			<option value="derivado">Derivado</option>
			<option value="derivado_expediente">Derivado a expediente</option>
			<option value="pendiente_informacion">Pendiente info</option>
			<option value="cancelado">Cancelado</option>
			<option value="reabierto">Reabierto</option>
		</select>
	</div>
	<div>
		<label for="f-canal" class="block text-sm font-medium mb-1">Canal</label>
		<select id="f-canal" bind:value={filtroCanal} class="px-3 py-2 border border-border rounded-md text-sm">
			<option value="">Todos</option>
			{#each data.canales as canal}
				<option value={canal.id}>{canal.nombre}</option>
			{/each}
		</select>
	</div>
	<div>
		<label for="f-tipo" class="block text-sm font-medium mb-1">Tipo</label>
		<select id="f-tipo" bind:value={filtroTipo} class="px-3 py-2 border border-border rounded-md text-sm">
			<option value="">Todos</option>
			{#each data.tipos as tipo}
				<option value={tipo.id}>{tipo.nombre}</option>
			{/each}
		</select>
	</div>
	<div>
		<label for="f-prioridad" class="block text-sm font-medium mb-1">Prioridad</label>
		<select id="f-prioridad" bind:value={filtroPrioridad} class="px-3 py-2 border border-border rounded-md text-sm">
			<option value="">Todas</option>
			<option value="baja">Baja</option>
			<option value="media">Media</option>
			<option value="alta">Alta</option>
			<option value="critica">Crítica</option>
		</select>
	</div>
	<div class="flex items-end">
		<button type="submit" class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark">Filtrar</button>
	</div>
</form>

{#if data.reclamos.length === 0}
	<p class="text-text-muted">Todavía no hay reclamos cargados.</p>
{:else}
	<div class="overflow-x-auto">
		<table class="w-full border-collapse text-sm">
			<thead>
				<tr class="border-b border-border text-left">
					<th class="py-2.5 px-2 font-semibold">Código</th>
					<th class="py-2.5 px-2 font-semibold">Título</th>
					<th class="py-2.5 px-2 font-semibold">Reclamante</th>
					<th class="py-2.5 px-2 font-semibold">Inspección</th>
					<th class="py-2.5 px-2 font-semibold">Tipo</th>
					<th class="py-2.5 px-2 font-semibold">Prioridad</th>
					<th class="py-2.5 px-2 font-semibold">Estado</th>
					<th class="py-2.5 px-2 font-semibold">Expediente</th>
					<th class="py-2.5 px-2 font-semibold">Fecha</th>
				</tr>
			</thead>
			<tbody>
				{#each data.reclamos as r}
					<tr class="border-b border-border hover:bg-bg">
						<td class="py-2.5 px-2"><a href={`/reclamos/${r.id}`} class="text-primary hover:underline">{r.codigo_reclamo}</a></td>
						<td class="py-2.5 px-2">{r.titulo}</td>
						<td class="py-2.5 px-2">{(r.reclamante_nombre ?? '') + ' ' + (r.reclamante_apellido ?? '')}</td>
						<td class="py-2.5 px-2">{nombreInspeccion(r.inspeccion_id)}</td>
						<td class="py-2.5 px-2">{nombreTipo(r.tipo_id)}</td>
						<td class="py-2.5 px-2"><span style="color: {colorPrioridad(r.prioridad)}" class="font-semibold">{r.prioridad}</span></td>
						<td class="py-2.5 px-2">
							<span class="inline-block px-2 py-0.5 rounded-full text-xs bg-[#eef2ee] text-primary">{r.estado}</span>
						</td>
						<td class="py-2.5 px-2">
							{#if r.expediente_id}
								<a href={`/expedientes/${r.expediente_id}`} class="text-primary hover:underline">{r.numero_expediente ?? r.expediente_id}</a>
							{:else}
								—
							{/if}
						</td>
						<td class="py-2.5 px-2">{new Date(r.fecha_creacion).toLocaleDateString('es-AR')}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{/if}
