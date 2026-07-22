<script lang="ts">
	import type { PageData } from './$types';
	import { goto } from '$app/navigation';
	import Paginacion from '$lib/components/Paginacion.svelte';

	export let data: PageData;

	const totalPages = Math.ceil(data.total / data.pageSize);

	function nombreSector(sectorId: number): string {
		return data.sectores.find((s) => s.id === sectorId)?.nombre ?? `Sector ${sectorId}`;
	}

	let busqueda = data.filtros?.q || '';
	let fechaDesde = data.filtros?.fecha_desde || '';
	let fechaHasta = data.filtros?.fecha_hasta || '';

	type SortKey = 'numero_expediente' | 'asunto' | 'iniciador_nombre' | 'sector_actual_id' | 'fecha_vencimiento' | 'estado' | 'fecha_ultima_actualizacion';

	let sortColumn: SortKey = 'fecha_ultima_actualizacion';
	let sortAsc = false;

	function toggleSort(col: SortKey) {
		if (sortColumn === col) {
			sortAsc = !sortAsc;
		} else {
			sortColumn = col;
			sortAsc = col === 'numero_expediente';
		}
	}

	function arrow(col: SortKey): string {
		if (sortColumn !== col) return '';
		return sortAsc ? ' ▲' : ' ▼';
	}

	$: expedientesOrdenados = [...data.expedientes].sort((a, b) => {
		let va: string | number | null;
		let vb: string | number | null;
		switch (sortColumn) {
			case 'numero_expediente':
				va = a.numero_expediente;
				vb = b.numero_expediente;
				break;
			case 'asunto':
				va = a.asunto;
				vb = b.asunto;
				break;
			case 'iniciador_nombre':
				va = a.iniciador_nombre;
				vb = b.iniciador_nombre;
				break;
			case 'sector_actual_id':
				va = nombreSector(a.sector_actual_id);
				vb = nombreSector(b.sector_actual_id);
				break;
			case 'fecha_vencimiento':
				va = a.ultimo_vencimiento ?? '';
				vb = b.ultimo_vencimiento ?? '';
				break;
			case 'estado':
				va = a.estado;
				vb = b.estado;
				break;
			case 'fecha_ultima_actualizacion':
				va = a.fecha_ultima_actualizacion;
				vb = b.fecha_ultima_actualizacion;
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

	function buscar() {
		const params = new URLSearchParams();
		if (busqueda) params.set('q', busqueda);
		if (fechaDesde) params.set('fecha_desde', fechaDesde);
		if (fechaHasta) params.set('fecha_hasta', fechaHasta);
		// Resetear a página 1 al buscar
		const query = params.toString() ? `?${params.toString()}` : '';
		goto(`/expedientes${query}`, { replaceState: true });
	}

	function navigatePage(e: CustomEvent<number>) {
		const params = new URLSearchParams();
		if (busqueda) params.set('q', busqueda);
		if (fechaDesde) params.set('fecha_desde', fechaDesde);
		if (fechaHasta) params.set('fecha_hasta', fechaHasta);
		params.set('page', String(e.detail));
		goto(`/expedientes?${params.toString()}`, { replaceState: true });
	}
</script>

<div class="flex justify-between items-center mb-4">
	<h1 class="text-2xl font-bold">Expedientes</h1>
	<a class="bg-primary text-white px-4 py-2 rounded-md no-underline text-sm hover:bg-primary-dark" href="/expedientes/nuevo">+ Nuevo expediente</a>
</div>

<form on:submit|preventDefault={buscar} class="flex gap-4 items-end flex-wrap mb-6">
	<div>
		<label for="busqueda" class="block text-sm font-medium mb-1">Buscar</label>
		<input id="busqueda" bind:value={busqueda} placeholder="Número, GDE, asunto, iniciador, DNI, CC, PP..." class="w-60 px-3 py-2 border border-border rounded-md text-sm" />
	</div>
	<div>
		<label for="fecha-desde" class="block text-sm font-medium mb-1">Desde</label>
		<input id="fecha-desde" type="date" bind:value={fechaDesde} class="px-3 py-2 border border-border rounded-md text-sm" />
	</div>
	<div>
		<label for="fecha-hasta" class="block text-sm font-medium mb-1">Hasta</label>
		<input id="fecha-hasta" type="date" bind:value={fechaHasta} class="px-3 py-2 border border-border rounded-md text-sm" />
	</div>
	<button type="submit" class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark">Buscar</button>
	{#if busqueda || fechaDesde || fechaHasta}
		<a href="/expedientes" class="self-end text-sm text-primary hover:underline">Limpiar filtros</a>
	{/if}
</form>

{#if data.expedientes.length === 0}
	<p class="text-text-muted">Todavía no hay expedientes cargados.</p>
{:else}
	<div class="overflow-x-auto">
		<table class="w-full border-collapse text-sm">
			<thead>
				<tr class="border-b border-border text-left">
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('numero_expediente')}>Número{arrow('numero_expediente')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('asunto')}>Asunto{arrow('asunto')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('iniciador_nombre')}>Iniciador{arrow('iniciador_nombre')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('sector_actual_id')}>Sector actual{arrow('sector_actual_id')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('fecha_vencimiento')}>Vencimiento{arrow('fecha_vencimiento')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('estado')}>Estado{arrow('estado')}</th>
					<th class="py-2.5 px-2 font-semibold cursor-pointer select-none hover:text-primary" on:click={() => toggleSort('fecha_ultima_actualizacion')}>Última actualización{arrow('fecha_ultima_actualizacion')}</th>
				</tr>
			</thead>
			<tbody>
				{#each expedientesOrdenados as exp}
					<tr class="border-b border-border hover:bg-bg">
						<td class="py-2.5 px-2"><a href={`/expedientes/${exp.id}`} class="text-primary hover:underline">{exp.numero_expediente}</a></td>
						<td class="py-2.5 px-2">{exp.asunto}</td>
						<td class="py-2.5 px-2">
							{exp.iniciador_nombre}
							{#if exp.iniciador_cc || exp.iniciador_pp}
								<br /><small class="text-text-muted">
									{#if exp.iniciador_cc}CC: {exp.iniciador_cc}{/if}
									{#if exp.iniciador_pp}{#if exp.iniciador_cc} | {/if}PP: {exp.iniciador_pp}{/if}
								</small>
							{/if}
						</td>
						<td class="py-2.5 px-2">{nombreSector(exp.sector_actual_id)}</td>
						<td class="py-2.5 px-2">
							{#if exp.ultimo_vencimiento}
								{new Date(exp.ultimo_vencimiento).toLocaleDateString('es-AR')}
							{:else}
								—
							{/if}
						</td>
						<td class="py-2.5 px-2">
							<span class="inline-block px-2 py-0.5 rounded-full text-xs {exp.estado === 'archivado' ? 'bg-red-100 text-red-700' : 'bg-[#eef2ee] text-primary'}">{exp.estado}</span>
						</td>
						<td class="py-2.5 px-2">{new Date(exp.fecha_ultima_actualizacion).toLocaleString('es-AR')}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>

	<Paginacion page={data.page} {totalPages} on:navigate={navigatePage} />

	<p class="text-sm text-text-muted mt-1">Mostrando {data.expedientes.length} de {data.total} expedientes</p>
{/if}
