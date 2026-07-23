<script lang="ts">
	import type { PageData } from './$types';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import Paginacion from '$lib/components/Paginacion.svelte';

	export let data: PageData;

	const totalPages = Math.ceil(data.total / data.pageSize);

	let filtroEstado = '';
	let filtroNotificadoTipo = '';
	let busqueda = '';
	let fechaDesde = '';
	let fechaHasta = '';

	onMount(() => {
		const params = new URLSearchParams(window.location.search);
		busqueda = params.get('q') ?? '';
		fechaDesde = params.get('fecha_desde') ?? '';
		fechaHasta = params.get('fecha_hasta') ?? '';
	});

	function aplicarFiltros() {
		const params = new URLSearchParams();
		if (filtroEstado) params.set('estado', filtroEstado);
		if (filtroNotificadoTipo) params.set('notificado_tipo', filtroNotificadoTipo);
		if (busqueda.trim()) params.set('q', busqueda.trim());
		if (fechaDesde) params.set('fecha_desde', fechaDesde);
		if (fechaHasta) params.set('fecha_hasta', fechaHasta);
		const qs = params.toString();
		goto(`/notificaciones${qs ? `?${qs}` : ''}`, { replaceState: true, keepFocus: true });
	}

	function limpiarFiltros() {
		filtroEstado = '';
		filtroNotificadoTipo = '';
		busqueda = '';
		fechaDesde = '';
		fechaHasta = '';
		goto('/notificaciones', { replaceState: true, keepFocus: true });
	}

	function navigatePage(e: CustomEvent<number>) {
		const params = new URLSearchParams();
		if (filtroEstado) params.set('estado', filtroEstado);
		if (filtroNotificadoTipo) params.set('notificado_tipo', filtroNotificadoTipo);
		if (busqueda.trim()) params.set('q', busqueda.trim());
		if (fechaDesde) params.set('fecha_desde', fechaDesde);
		if (fechaHasta) params.set('fecha_hasta', fechaHasta);
		params.set('page', String(e.detail));
		goto(`/notificaciones?${params.toString()}`, { replaceState: true, keepFocus: true });
	}

	function nombreTipo(tipoId: number | null | undefined): string {
		if (!tipoId) return '—';
		return data.tiposNotificacion.find((t) => t.id === tipoId)?.nombre ?? `Tipo ${tipoId}`;
	}

	function nombreMedio(medioId: number | null | undefined): string {
		if (!medioId) return '—';
		return data.mediosNotificacion.find((m) => m.id === medioId)?.nombre ?? `Medio ${medioId}`;
	}

	function colorEstado(e: string): string {
		switch (e) {
			case 'emitida': return '#16a34a';
			case 'notificada': return '#16a34a';
			case 'respondida': return '#16a34a';
			case 'vencida': return '#dc2626';
			case 'cumplida': return '#dc2626';
			case 'cerrada': return '#dc2626';
			default: return 'inherit';
		}
	}

	function bgEstado(e: string): string {
		switch (e) {
			case 'emitida': return '#dcfce7';
			case 'notificada': return '#dcfce7';
			case 'respondida': return '#dcfce7';
			case 'vencida': return '#fee2e2';
			case 'cumplida': return '#fee2e2';
			case 'cerrada': return '#fee2e2';
			default: return '#f3f4f6';
		}
	}

	// --- Ordenamiento ---
	type SortKey = 'codigo_notificacion' | 'notificado_nombre' | 'motivo' | 'tipo' | 'medio' | 'estado' | 'fecha_emision' | 'fecha_vencimiento_respuesta';
	let sortColumn: SortKey = 'fecha_emision';
	let sortAsc = false;

	function toggleSort(col: SortKey) {
		if (sortColumn === col) {
			sortAsc = !sortAsc;
		} else {
			sortColumn = col;
			sortAsc = col === 'codigo_notificacion';
		}
	}

	function arrow(col: SortKey): string {
		if (sortColumn !== col) return '';
		return sortAsc ? ' ▲' : ' ▼';
	}

	$: notificacionesOrdenadas = [...data.notificaciones].sort((a, b) => {
		let va: string | number | null;
		let vb: string | number | null;
		switch (sortColumn) {
			case 'codigo_notificacion':
				va = a.codigo_notificacion;
				vb = b.codigo_notificacion;
				break;
			case 'notificado_nombre':
				va = a.notificado_nombre ?? '';
				vb = b.notificado_nombre ?? '';
				break;
			case 'motivo':
				va = a.motivo;
				vb = b.motivo;
				break;
			case 'tipo':
				va = nombreTipo(a.tipo_notificacion_id);
				vb = nombreTipo(b.tipo_notificacion_id);
				break;
			case 'medio':
				va = nombreMedio(a.medio_notificacion_id);
				vb = nombreMedio(b.medio_notificacion_id);
				break;
			case 'estado':
				va = a.estado;
				vb = b.estado;
				break;
			case 'fecha_emision':
				va = a.fecha_emision ?? '';
				vb = b.fecha_emision ?? '';
				break;
			case 'fecha_vencimiento_respuesta':
				va = a.fecha_vencimiento_respuesta ?? '';
				vb = b.fecha_vencimiento_respuesta ?? '';
				break;
			default:
				return 0;
		}
		if (va == null && vb == null) return 0;
		if (va == null) return 1;
		if (vb == null) return -1;
		const cmp = String(va).localeCompare(String(vb), 'es', { numeric: true });
		return sortAsc ? cmp : -cmp;
	});
</script>

<div class="flex justify-between items-center mb-4">
	<h1 class="text-2xl font-bold">Notificaciones</h1>
	<a class="bg-primary text-white px-4 py-2 rounded-md no-underline text-sm hover:bg-primary-dark" href="/notificaciones/nuevo">+ Nueva notificación</a>
</div>

<!-- Filtros + Búsqueda -->
<form on:submit|preventDefault={aplicarFiltros} class="flex gap-3 flex-wrap mb-4">
	<div>
		<label for="f-buscar" class="block text-sm font-medium mb-1">Buscar</label>
		<input id="f-buscar" bind:value={busqueda} placeholder="Código, nombre, motivo..." class="w-56 px-3 py-2 border border-border rounded-md text-sm" />
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
			<option value="emitida">Emitida</option>
			<option value="notificada">Notificada</option>
			<option value="respondida">Respondida</option>
			<option value="vencida">Vencida</option>
			<option value="cumplida">Cumplida</option>
			<option value="cerrada">Cerrada</option>
		</select>
	</div>
	<div>
		<label for="f-notificado-tipo" class="block text-sm font-medium mb-1">Tipo notificado</label>
		<select id="f-notificado-tipo" bind:value={filtroNotificadoTipo} class="px-3 py-2 border border-border rounded-md text-sm">
			<option value="">Todos</option>
			<option value="regante">Regante</option>
			<option value="tercero">Tercero</option>
		</select>
	</div>
	<div class="flex items-end gap-2">
		<button type="submit" class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark">Filtrar</button>
		<button type="button" on:click={limpiarFiltros} class="bg-white border border-border px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-bg">Limpiar</button>
	</div>
</form>

{#if data.notificaciones.length === 0}
	<p class="text-text-muted">Todavía no hay notificaciones cargadas.</p>
{:else}
	<div class="overflow-x-auto">
		<table class="w-full border-collapse text-sm">
			<thead>
				<tr class="border-b border-border text-left">
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('codigo_notificacion')}>Código{arrow('codigo_notificacion')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('notificado_nombre')}>Notificado{arrow('notificado_nombre')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('motivo')}>Motivo{arrow('motivo')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('tipo')}>Tipo{arrow('tipo')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('medio')}>Medio{arrow('medio')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('estado')}>Estado{arrow('estado')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('fecha_emision')}>Emisión{arrow('fecha_emision')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('fecha_vencimiento_respuesta')}>Vencimiento{arrow('fecha_vencimiento_respuesta')}</th>
				</tr>
			</thead>
			<tbody>
				{#each notificacionesOrdenadas as n}
					<tr class="border-b border-border hover:bg-bg">
						<td class="py-2.5 px-2"><a href={`/notificaciones/${n.id}`} class="text-primary hover:underline">{n.codigo_notificacion}</a></td>
						<td class="py-2.5 px-2">{n.notificado_nombre ?? '—'}</td>
						<td class="py-2.5 px-2">{n.motivo}</td>
						<td class="py-2.5 px-2">{nombreTipo(n.tipo_notificacion_id)}</td>
						<td class="py-2.5 px-2">{nombreMedio(n.medio_notificacion_id)}</td>
						<td class="py-2.5 px-2">
							<span class="inline-block px-2 py-0.5 rounded-full text-xs font-medium" style="color: {colorEstado(n.estado)}; background: {bgEstado(n.estado)}">{n.estado}</span>
						</td>
						<td class="py-2.5 px-2">{n.fecha_emision ? new Date(n.fecha_emision).toLocaleDateString('es-AR') : '—'}</td>
						<td class="py-2.5 px-2">{n.fecha_vencimiento_respuesta ? new Date(n.fecha_vencimiento_respuesta).toLocaleDateString('es-AR') : '—'}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>

	<Paginacion page={data.page} {totalPages} on:navigate={navigatePage} />

	<p class="text-sm text-text-muted mt-1">Mostrando {data.notificaciones.length} de {data.total} notificaciones</p>
{/if}
