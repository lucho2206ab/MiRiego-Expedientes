<script lang="ts">
	import type { PageData } from './$types';
	import { expedientesVencimientos, reclamosVencimientos } from '$lib/api/dashboard';
	import type { SectorConteo, ExpedienteVencido, InspeccionConteo, ReclamoVencido } from '$lib/types/dashboard';

	export let data: PageData;

	// --- Tab activa ---
	let tabActiva: 'expedientes' | 'reclamos' = 'expedientes';

	// --- Expedientes ---
	let sectorSeleccionado: number | '' = '';
	let estadoExp = 'vencido';
	let diasUmbral = 5;
	let conteoExp: SectorConteo[] = [];
	let detalleExp: ExpedienteVencido[] = [];
	let cargandoExp = false;
	let sectorDetalleExp: number | null = null;

	// --- Reclamos ---
	let inspeccionSeleccionada: number | '' = '';
	let estadoRec = 'vencido';
	let horasUmbral = 6;
	let conteoRec: InspeccionConteo[] = [];
	let detalleRec: ReclamoVencido[] = [];
	let cargandoRec = false;
	let inspeccionDetalleRec: number | null = null;

	// --- Expedientes: cargar conteo ---
	async function cargarConteoExp() {
		cargandoExp = true;
		sectorDetalleExp = null;
		detalleExp = [];
		try {
			conteoExp = await expedientesVencimientos({ estado: estadoExp, dias_umbral: diasUmbral }) as SectorConteo[];
		} catch (e) {
			conteoExp = [];
		} finally {
			cargandoExp = false;
		}
	}

	// --- Expedientes: cargar detalle de un sector ---
	async function cargarDetalleExp(sectorId: number) {
		if (sectorDetalleExp === sectorId) {
			sectorDetalleExp = null;
			detalleExp = [];
			return;
		}
		cargandoExp = true;
		try {
			detalleExp = await expedientesVencimientos({ sector_id: sectorId, estado: estadoExp, dias_umbral: diasUmbral }) as ExpedienteVencido[];
			sectorDetalleExp = sectorId;
		} catch (e) {
			detalleExp = [];
		} finally {
			cargandoExp = false;
		}
	}

	// --- Reclamos: cargar conteo ---
	async function cargarConteoRec() {
		cargandoRec = true;
		inspeccionDetalleRec = null;
		detalleRec = [];
		try {
			conteoRec = await reclamosVencimientos({ estado: estadoRec, horas_umbral: horasUmbral }) as InspeccionConteo[];
		} catch (e) {
			conteoRec = [];
		} finally {
			cargandoRec = false;
		}
	}

	// --- Reclamos: cargar detalle de una inspección ---
	async function cargarDetalleRec(insId: number) {
		if (inspeccionDetalleRec === insId) {
			inspeccionDetalleRec = null;
			detalleRec = [];
			return;
		}
		cargandoRec = true;
		try {
			detalleRec = await reclamosVencimientos({ inspeccion_id: insId, estado: estadoRec, horas_umbral: horasUmbral }) as ReclamoVencido[];
			inspeccionDetalleRec = insId;
		} catch (e) {
			detalleRec = [];
		} finally {
			cargandoRec = false;
		}
	}

	function fmtFecha(s: string | null | undefined): string {
		if (!s) return '—';
		return new Date(s).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
	}

	function limpiarFiltrosExp() {
		estadoExp = 'vencido';
		diasUmbral = 5;
		conteoExp = [];
		detalleExp = [];
		sectorDetalleExp = null;
	}

	function limpiarFiltrosRec() {
		estadoRec = 'vencido';
		horasUmbral = 6;
		conteoRec = [];
		detalleRec = [];
		inspeccionDetalleRec = null;
	}
</script>

<h1 class="text-2xl font-bold mb-4">Dashboard</h1>

<!-- Tabs -->
<div class="flex gap-1 border-b border-border mb-4">
	<button
		class="px-4 py-2 text-sm font-medium cursor-pointer border-b-2 -mb-px {tabActiva === 'expedientes' ? 'border-primary text-primary' : 'border-transparent text-text-muted hover:text-text'}"
		on:click={() => tabActiva = 'expedientes'}
	>
		Expedientes por sector
	</button>
	<button
		class="px-4 py-2 text-sm font-medium cursor-pointer border-b-2 -mb-px {tabActiva === 'reclamos' ? 'border-primary text-primary' : 'border-transparent text-text-muted hover:text-text'}"
		on:click={() => tabActiva = 'reclamos'}
	>
		Reclamos por inspección
	</button>
</div>

{#if tabActiva === 'expedientes'}
	<!-- Filtros expedientes -->
	<div class="flex gap-3 items-end mb-4">
		<div>
			<label for="f-estado-exp" class="block text-sm font-medium mb-1">Estado</label>
			<select id="f-estado-exp" bind:value={estadoExp} class="px-3 py-2 border border-border rounded-md text-sm">
				<option value="vencido">Vencidos</option>
				<option value="por_vencer">Por vencer</option>
			</select>
		</div>
		<div>
			<label for="f-dias" class="block text-sm font-medium mb-1">Días umbral</label>
			<input id="f-dias" type="number" bind:value={diasUmbral} min="1" max="365" class="w-20 px-3 py-2 border border-border rounded-md text-sm" />
		</div>
		<button on:click={cargarConteoExp} class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark">Consultar</button>
		<button on:click={limpiarFiltrosExp} class="bg-white border border-border px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-bg">Limpiar</button>
	</div>

	{#if cargandoExp}
		<p class="text-text-muted text-sm">Cargando...</p>
	{:else if conteoExp.length === 0}
		<p class="text-text-muted text-sm">Presioná "Consultar" para ver los vencimientos por sector.</p>
	{:else}
		<!-- Tabla de conteos -->
		<div class="overflow-x-auto">
			<table class="w-full border-collapse text-sm">
				<thead>
					<tr class="border-b border-border text-left">
						<th class="py-2.5 px-2 font-semibold">Sector</th>
						<th class="py-2.5 px-2 font-semibold text-right">{estadoExp === 'vencido' ? 'Vencidos' : 'Por vencer'}</th>
						<th class="py-2.5 px-2 font-semibold">Detalle</th>
					</tr>
				</thead>
				<tbody>
					{#each conteoExp as c}
						<tr class="border-b border-border hover:bg-bg">
							<td class="py-2.5 px-2">{c.sector_nombre}</td>
							<td class="py-2.5 px-2 text-right font-semibold {c.total > 0 ? 'text-danger' : ''}">{c.total}</td>
							<td class="py-2.5 px-2">
								<button
									on:click={() => cargarDetalleExp(c.sector_id)}
									class="text-primary text-sm hover:underline cursor-pointer"
								>
									{sectorDetalleExp === c.sector_id ? 'Ocultar' : 'Ver detalle'}
								</button>
							</td>
						</tr>
						{#if sectorDetalleExp === c.sector_id && detalleExp.length > 0}
							{#each detalleExp as exp}
								<tr class="border-b border-border bg-bg">
									<td class="py-1.5 px-2 pl-6 text-sm">
										<a href={`/expedientes/${exp.id}`} class="text-primary hover:underline">{exp.numero_expediente}</a>
									</td>
									<td class="py-1.5 px-2 text-sm" colspan="1">{exp.asunto}</td>
									<td class="py-1.5 px-2 text-sm text-right">{fmtFecha(exp.fecha_vencimiento_effectiva)}</td>
								</tr>
							{/each}
						{/if}
						{#if sectorDetalleExp === c.sector_id && detalleExp.length === 0}
							<tr class="border-b border-border bg-bg">
								<td colspan="3" class="py-2 px-2 pl-6 text-sm text-text-muted">Sin expedientes en esta condición.</td>
							</tr>
						{/if}
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
{:else}
	<!-- Reclamos por inspección -->
	<div class="flex gap-3 items-end mb-4">
		<div>
			<label for="f-estado-rec" class="block text-sm font-medium mb-1">Estado</label>
			<select id="f-estado-rec" bind:value={estadoRec} class="px-3 py-2 border border-border rounded-md text-sm">
				<option value="vencido">Vencidos</option>
				<option value="por_vencer">Por vencer</option>
			</select>
		</div>
		<div>
			<label for="f-horas" class="block text-sm font-medium mb-1">Horas umbral</label>
			<input id="f-horas" type="number" bind:value={horasUmbral} min="1" max="720" class="w-20 px-3 py-2 border border-border rounded-md text-sm" />
		</div>
		<button on:click={cargarConteoRec} class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark">Consultar</button>
		<button on:click={limpiarFiltrosRec} class="bg-white border border-border px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-bg">Limpiar</button>
	</div>

	{#if cargandoRec}
		<p class="text-text-muted text-sm">Cargando...</p>
	{:else if conteoRec.length === 0}
		<p class="text-text-muted text-sm">Presioná "Consultar" para ver los vencimientos por inspección.</p>
	{:else}
		<div class="overflow-x-auto">
			<table class="w-full border-collapse text-sm">
				<thead>
					<tr class="border-b border-border text-left">
						<th class="py-2.5 px-2 font-semibold">Inspección</th>
						<th class="py-2.5 px-2 font-semibold text-right">{estadoRec === 'vencido' ? 'Vencidos' : 'Por vencer'}</th>
						<th class="py-2.5 px-2 font-semibold">Detalle</th>
					</tr>
				</thead>
				<tbody>
					{#each conteoRec as c}
						<tr class="border-b border-border hover:bg-bg">
							<td class="py-2.5 px-2">{c.inspeccion_nombre}</td>
							<td class="py-2.5 px-2 text-right font-semibold {c.total > 0 ? 'text-danger' : ''}">{c.total}</td>
							<td class="py-2.5 px-2">
								<button
									on:click={() => cargarDetalleRec(c.inspeccion_id)}
									class="text-primary text-sm hover:underline cursor-pointer"
								>
									{inspeccionDetalleRec === c.inspeccion_id ? 'Ocultar' : 'Ver detalle'}
								</button>
							</td>
						</tr>
						{#if inspeccionDetalleRec === c.inspeccion_id && detalleRec.length > 0}
							{#each detalleRec as rec}
								<tr class="border-b border-border bg-bg">
									<td class="py-1.5 px-2 pl-6 text-sm">
										<a href={`/reclamos/${rec.id}`} class="text-primary hover:underline">{rec.codigo_reclamo}</a>
									</td>
									<td class="py-1.5 px-2 text-sm">{rec.titulo}</td>
									<td class="py-1.5 px-2 text-sm text-right">{fmtFecha(rec.fecha_limite_respuesta)}</td>
								</tr>
							{/each}
						{/if}
						{#if inspeccionDetalleRec === c.inspeccion_id && detalleRec.length === 0}
							<tr class="border-b border-border bg-bg">
								<td colspan="3" class="py-2 px-2 pl-6 text-sm text-text-muted">Sin reclamos en esta condición.</td>
							</tr>
						{/if}
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
{/if}
