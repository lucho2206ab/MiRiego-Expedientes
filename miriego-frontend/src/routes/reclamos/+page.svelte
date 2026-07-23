<script lang="ts">
	import type { PageData } from './$types';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import Paginacion from '$lib/components/Paginacion.svelte';

	export let data: PageData;

	const totalPages = Math.ceil(data.total / data.pageSize);

	let filtroEstado = '';
	let filtroInspeccion: number | '' = '';
	let filtroCanal: number | '' = '';
	let filtroTipo = '';
	let filtroPrioridad = '';
	let busqueda = '';
	let fechaDesde = '';
	let fechaHasta = '';

	onMount(() => {
		const params = new URLSearchParams(window.location.search);
		busqueda = params.get('q') ?? '';
		fechaDesde = params.get('fecha_desde') ?? '';
		fechaHasta = params.get('fecha_hasta') ?? '';
		const insParam = params.get('inspeccion_id');
		if (insParam) filtroInspeccion = Number(insParam);
		const canalParam = params.get('canal_id');
		if (canalParam) filtroCanal = Number(canalParam);
	});

	$: canalesFiltrados = filtroInspeccion
		? data.canales.filter((c) => c.inspeccion_id === filtroInspeccion)
		: data.canales;

	function onInspeccionChange() {
		filtroCanal = '';
	}

	function aplicarFiltros() {
		const params = new URLSearchParams();
		if (filtroEstado) params.set('estado', filtroEstado);
		if (filtroInspeccion !== '') params.set('inspeccion_id', String(filtroInspeccion));
		if (filtroCanal !== '') params.set('canal_id', String(filtroCanal));
		if (filtroTipo) params.set('tipo_id', filtroTipo);
		if (filtroPrioridad) params.set('prioridad', filtroPrioridad);
		if (busqueda.trim()) params.set('q', busqueda.trim());
		if (fechaDesde) params.set('fecha_desde', fechaDesde);
		if (fechaHasta) params.set('fecha_hasta', fechaHasta);
		const qs = params.toString();
		goto(`/reclamos${qs ? `?${qs}` : ''}`, { replaceState: true, keepFocus: true });
	}

	function limpiarFiltros() {
		filtroEstado = '';
		filtroInspeccion = '';
		filtroCanal = '';
		filtroTipo = '';
		filtroPrioridad = '';
		busqueda = '';
		fechaDesde = '';
		fechaHasta = '';
		goto('/reclamos', { replaceState: true, keepFocus: true });
	}

	function navigatePage(e: CustomEvent<number>) {
		const params = new URLSearchParams();
		if (filtroEstado) params.set('estado', filtroEstado);
		if (filtroInspeccion !== '') params.set('inspeccion_id', String(filtroInspeccion));
		if (filtroCanal !== '') params.set('canal_id', String(filtroCanal));
		if (filtroTipo) params.set('tipo_id', filtroTipo);
		if (filtroPrioridad) params.set('prioridad', filtroPrioridad);
		if (busqueda.trim()) params.set('q', busqueda.trim());
		if (fechaDesde) params.set('fecha_desde', fechaDesde);
		if (fechaHasta) params.set('fecha_hasta', fechaHasta);
		params.set('page', String(e.detail));
		goto(`/reclamos?${params.toString()}`, { replaceState: true, keepFocus: true });
	}

	function nombreInspeccion(inspeccionId: number | null | undefined): string {
		if (!inspeccionId) return '—';
		return data.inspecciones.find((i) => i.id === inspeccionId)?.nombre ?? `Inspección ${inspeccionId}`;
	}

	function nombreCanal(canalId: number | null | undefined): string {
		if (!canalId) return '—';
		return data.canales.find((c) => c.id === canalId)?.nombre ?? `Canal ${canalId}`;
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

	const ESTADOS_TERMINALES = ['resuelto', 'cerrado', 'rechazado', 'cancelado', 'derivado_expediente'];

	function vencimientoInfo(r: { fecha_limite_respuesta?: string | null; estado: string; prioridad: string }): { texto: string; color: string; bg: string } {
		if (!r.fecha_limite_respuesta) return { texto: '—', color: '#888', bg: 'transparent' };
		if (ESTADOS_TERMINALES.includes(r.estado)) return { texto: 'Congelado', color: '#6b7280', bg: '#f3f4f6' };
		const ahora = new Date();
		const limite = new Date(r.fecha_limite_respuesta);
		const diffMs = limite.getTime() - ahora.getTime();
		const diffHs = diffMs / (1000 * 60 * 60);
		if (diffMs <= 0) return { texto: 'Vencido', color: '#fff', bg: 'var(--color-danger)' };
		if (diffHs < 6) return { texto: `${Math.round(diffHs)}h`, color: '#856404', bg: 'var(--color-warning-bg)' };
		return { texto: `${Math.round(diffHs)}h`, color: colorPrioridad(r.prioridad), bg: 'transparent' };
	}

	function vencimientoSortKey(r: { fecha_limite_respuesta?: string | null; estado: string }): number {
		if (!r.fecha_limite_respuesta) return 1;
		if (ESTADOS_TERMINALES.includes(r.estado)) return 2;
		return 0;
	}

	// --- Ordenamiento ---
	type SortKey = 'codigo_reclamo' | 'titulo' | 'reclamante' | 'inspeccion' | 'tipo' | 'prioridad' | 'estado' | 'expediente' | 'fecha_creacion' | 'vencimiento';
	let sortColumn: SortKey = 'fecha_creacion';
	let sortAsc = false;

	function toggleSort(col: SortKey) {
		if (sortColumn === col) {
			sortAsc = !sortAsc;
		} else {
			sortColumn = col;
			sortAsc = col === 'codigo_reclamo';
		}
	}

	function arrow(col: SortKey): string {
		if (sortColumn !== col) return '';
		return sortAsc ? ' ▲' : ' ▼';
	}

	$: reclamosOrdenados = [...data.reclamos].sort((a, b) => {
		let va: string | number | null;
		let vb: string | number | null;
		switch (sortColumn) {
			case 'codigo_reclamo':
				va = a.codigo_reclamo;
				vb = b.codigo_reclamo;
				break;
			case 'titulo':
				va = a.titulo;
				vb = b.titulo;
				break;
			case 'reclamante':
				va = ((a.reclamante_nombre ?? '') + ' ' + (a.reclamante_apellido ?? '')).trim();
				vb = ((b.reclamante_nombre ?? '') + ' ' + (b.reclamante_apellido ?? '')).trim();
				break;
			case 'inspeccion':
				va = nombreInspeccion(a.inspeccion_id);
				vb = nombreInspeccion(b.inspeccion_id);
				break;
			case 'tipo':
				va = nombreTipo(a.tipo_id);
				vb = nombreTipo(b.tipo_id);
				break;
			case 'prioridad':
				const ordenPrioridad = { critica: 0, alta: 1, media: 2, baja: 3 };
				va = String(ordenPrioridad[a.prioridad as keyof typeof ordenPrioridad] ?? 4);
				vb = String(ordenPrioridad[b.prioridad as keyof typeof ordenPrioridad] ?? 4);
				break;
			case 'estado':
				va = a.estado;
				vb = b.estado;
				break;
			case 'expediente':
				va = a.numero_expediente ?? (a.expediente_id ? String(a.expediente_id) : '');
				vb = b.numero_expediente ?? (b.expediente_id ? String(b.expediente_id) : '');
				break;
			case 'fecha_creacion':
				va = a.fecha_creacion;
				vb = b.fecha_creacion;
				break;
			case 'vencimiento':
				va = String(vencimientoSortKey(a)) + (a.fecha_limite_respuesta ?? '');
				vb = String(vencimientoSortKey(b)) + (b.fecha_limite_respuesta ?? '');
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
		<label for="f-inspeccion" class="block text-sm font-medium mb-1">Inspección</label>
		<select id="f-inspeccion" bind:value={filtroInspeccion} on:change={onInspeccionChange} class="px-3 py-2 border border-border rounded-md text-sm">
			<option value="">Todas</option>
			{#each data.inspecciones as ins}
				<option value={ins.id}>{ins.nombre}</option>
			{/each}
		</select>
	</div>
	<div>
		<label for="f-canal" class="block text-sm font-medium mb-1">Canal</label>
		<select id="f-canal" bind:value={filtroCanal} disabled={filtroInspeccion === '' && canalesFiltrados.length === 0} class="px-3 py-2 border border-border rounded-md text-sm">
			<option value="">Todos</option>
			{#each canalesFiltrados as canal}
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
	<div class="flex items-end gap-2">
		<button type="submit" class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark">Filtrar</button>
		<button type="button" on:click={limpiarFiltros} class="bg-white border border-border px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-bg">Limpiar</button>
	</div>
</form>

{#if data.reclamos.length === 0}
	<p class="text-text-muted">Todavía no hay reclamos cargados.</p>
{:else}
	<div class="overflow-x-auto">
		<table class="w-full border-collapse text-sm">
			<thead>
				<tr class="border-b border-border text-left">
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('codigo_reclamo')}>Código{arrow('codigo_reclamo')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('titulo')}>Título{arrow('titulo')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('reclamante')}>Reclamante{arrow('reclamante')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('inspeccion')}>Inspección{arrow('inspeccion')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('tipo')}>Tipo{arrow('tipo')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('prioridad')}>Prioridad{arrow('prioridad')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('estado')}>Estado{arrow('estado')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('expediente')}>Expediente{arrow('expediente')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('fecha_creacion')}>Fecha{arrow('fecha_creacion')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('vencimiento')}>Vencimiento{arrow('vencimiento')}</th>
				</tr>
			</thead>
			<tbody>
				{#each reclamosOrdenados as r}
					<tr class="border-b border-border hover:bg-bg">
						<td class="py-2.5 px-2"><a href={`/reclamos/${r.id}`} class="text-primary hover:underline">{r.codigo_reclamo}</a></td>
						<td class="py-2.5 px-2">{r.titulo}</td>
						<td class="py-2.5 px-2">{(r.reclamante_nombre ?? '') + ' ' + (r.reclamante_apellido ?? '')}</td>
						<td class="py-2.5 px-2">{nombreInspeccion(r.inspeccion_id)}</td>
						<td class="py-2.5 px-2">{nombreTipo(r.tipo_id)}</td>
						<td class="py-2.5 px-2"><span style="color: {colorPrioridad(r.prioridad)}" class="font-semibold">{r.prioridad}</span></td>
						<td class="py-2.5 px-2">
							<span class="inline-block px-2 py-0.5 rounded-full text-xs {['cerrado','rechazado','cancelado','derivado_expediente'].includes(r.estado) ? 'bg-red-100 text-red-700' : 'bg-[#eef2ee] text-primary'}">{r.estado}</span>
						</td>
						<td class="py-2.5 px-2">
							{#if r.expediente_id}
								<a href={`/expedientes/${r.expediente_id}`} class="text-primary hover:underline">{r.numero_expediente ?? r.expediente_id}</a>
							{:else}
								—
							{/if}
						</td>
						<td class="py-2.5 px-2">{new Date(r.fecha_creacion).toLocaleDateString('es-AR')}</td>
						<td class="py-2.5 px-2"><span class="inline-block px-2 py-0.5 rounded-full text-xs font-medium" style="color: {vencimientoInfo(r).color}; background: {vencimientoInfo(r).bg}">{vencimientoInfo(r).texto}</span></td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>

	<Paginacion page={data.page} {totalPages} on:navigate={navigatePage} />

	<p class="text-sm text-text-muted mt-1">Mostrando {data.reclamos.length} de {data.total} reclamos</p>
{/if}
