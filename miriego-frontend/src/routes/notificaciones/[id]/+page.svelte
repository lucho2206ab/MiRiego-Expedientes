<script lang="ts">
	import type { PageData } from './$types';
	import { goto } from '$app/navigation';
	import { actualizarNotificacion, imprimirNotificacion } from '$lib/api/notificaciones';

	export let data: PageData;
	$: n = data.notificacion;

	const ESTADOS = ['emitida', 'notificada', 'respondida', 'vencida', 'cumplida', 'cerrada'] as const;
	$: nuevoEstado = n?.estado ?? 'emitida';
	let guardando = false;
	let msgExito = '';
	let msgError = '';
	let imprimiendo = false;

	function colorEstado(e: string): string {
		switch (e) {
			case 'emitida': return 'var(--color-primary)';
			case 'notificada': return '#2563eb';
			case 'respondida': return '#7c3aed';
			case 'vencida': return 'var(--color-danger)';
			case 'cumplida': return '#059669';
			case 'cerrada': return '#6b7280';
			default: return 'inherit';
		}
	}

	async function cambiarEstado() {
		if (nuevoEstado === n.estado) return;
		guardando = true;
		msgError = '';
		msgExito = '';
		try {
			await actualizarNotificacion(n.id, { estado: nuevoEstado });
			n = { ...n, estado: nuevoEstado };
			msgExito = 'Estado actualizado.';
		} catch (e) {
			msgError = e instanceof Error ? e.message : 'Error al actualizar';
		} finally {
			guardando = false;
		}
	}

	async function onImprimir() {
		imprimiendo = true;
		msgError = '';
		try {
			await imprimirNotificacion(n.id);
		} catch (e) {
			msgError = e instanceof Error ? e.message : 'Error al generar la cédula';
		} finally {
			imprimiendo = false;
		}
	}

	function fmtFecha(s: string | null | undefined): string {
		if (!s) return '—';
		return new Date(s).toLocaleDateString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
	}
</script>

<div class="flex justify-between items-center mb-4">
	<div>
		<a href="/notificaciones" class="text-primary text-sm hover:underline">&larr; Volver al listado</a>
		<h1 class="text-2xl font-bold mt-1">{n?.codigo_notificacion ?? '...'}</h1>
	</div>
	<div class="flex gap-2 items-center">
		<button on:click={onImprimir} disabled={imprimiendo} class="bg-white border border-border text-sm px-3 py-1.5 rounded-md cursor-pointer hover:bg-bg disabled:opacity-50">
			{imprimiendo ? 'Generando...' : 'Imprimir cédula'}
		</button>
		<span class="inline-block px-3 py-1 rounded-full text-sm font-semibold" style="color: {colorEstado(n?.estado ?? '')}; background: {n?.estado === 'vencida' ? '#fee2e2' : n?.estado === 'cerrada' ? '#f3f4f6' : '#eef2ee'}">{n?.estado ?? ''}</span>
	</div>
</div>

{#if n}
<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
	<!-- Notificado -->
	<div class="bg-surface border border-border rounded-lg p-4">
		<h2 class="font-semibold mb-2">Notificado</h2>
		<dl class="text-sm space-y-1">
			<div class="flex gap-2"><dt class="text-text-muted">Tipo:</dt><dd>{n.notificado_tipo}</dd></div>
			{#if n.notificado_nombre}<div class="flex gap-2"><dt class="text-text-muted">Nombre:</dt><dd>{n.notificado_nombre}</dd></div>{/if}
			{#if n.notificado_documento}<div class="flex gap-2"><dt class="text-text-muted">Documento:</dt><dd>{n.notificado_documento}</dd></div>{/if}
			{#if n.notificado_domicilio}<div class="flex gap-2"><dt class="text-text-muted">Domicilio:</dt><dd>{n.notificado_domicilio}</dd></div>{/if}
			{#if n.notificado_contacto}<div class="flex gap-2"><dt class="text-text-muted">Contacto:</dt><dd>{n.notificado_contacto}</dd></div>{/if}
			{#if n.cc}<div class="flex gap-2"><dt class="text-text-muted">CC:</dt><dd>{n.cc}</dd></div>{/if}
			{#if n.pp}<div class="flex gap-2"><dt class="text-text-muted">PP:</dt><dd>{n.pp}</dd></div>{/if}
		</dl>
	</div>

	<!-- Datos -->
	<div class="bg-surface border border-border rounded-lg p-4">
		<h2 class="font-semibold mb-2">Datos</h2>
		<dl class="text-sm space-y-1">
			<div class="flex gap-2"><dt class="text-text-muted">Motivo:</dt><dd>{n.motivo}</dd></div>
			{#if n.numero_expediente}<div class="flex gap-2"><dt class="text-text-muted">Expediente:</dt><dd><a href={`/expedientes/${n.expediente_id}`} class="text-primary hover:underline">{n.numero_expediente}</a></dd></div>{/if}
			<div class="flex gap-2"><dt class="text-text-muted">Emisión:</dt><dd>{fmtFecha(n.fecha_emision)}</dd></div>
			{#if n.fecha_notificacion}<div class="flex gap-2"><dt class="text-text-muted">Notificación:</dt><dd>{fmtFecha(n.fecha_notificacion)}</dd></div>{/if}
			{#if n.fecha_vencimiento_respuesta}<div class="flex gap-2"><dt class="text-text-muted">Vto. respuesta:</dt><dd>{fmtFecha(n.fecha_vencimiento_respuesta)}</dd></div>{/if}
		</dl>
	</div>

	<!-- Descripción -->
	<div class="bg-surface border border-border rounded-lg p-4 md:col-span-2">
		<h2 class="font-semibold mb-2">Descripción</h2>
		<p class="text-sm whitespace-pre-wrap">{n.descripcion}</p>
	</div>

	{#if n.observaciones}
		<div class="bg-surface border border-border rounded-lg p-4 md:col-span-2">
			<h2 class="font-semibold mb-2">Observaciones</h2>
			<p class="text-sm whitespace-pre-wrap">{n.observaciones}</p>
		</div>
	{/if}

	<!-- Cambiar estado -->
	<div class="bg-surface border border-border rounded-lg p-4 md:col-span-2">
		<h2 class="font-semibold mb-2">Cambiar estado</h2>
		<div class="flex gap-3 items-end">
			<div>
				<label for="nuevo-estado" class="block text-sm mb-1">Nuevo estado</label>
				<select id="nuevo-estado" bind:value={nuevoEstado} class="px-3 py-2 border border-border rounded-md text-sm">
					{#each ESTADOS as e}
						<option value={e}>{e}</option>
					{/each}
				</select>
			</div>
			<button on:click={cambiarEstado} disabled={guardando || nuevoEstado === n.estado} class="bg-primary text-white px-4 py-2 rounded-md text-sm cursor-pointer hover:bg-primary-dark disabled:opacity-50">
				{guardando ? 'Guardando...' : 'Actualizar'}
			</button>
		</div>
		{#if msgExito}<p class="text-primary text-sm mt-2">{msgExito}</p>{/if}
		{#if msgError}<div class="bg-danger-bg border border-danger-border text-danger px-4 py-3 rounded-md text-sm mt-2" role="alert">{msgError}</div>{/if}
	</div>
</div>
{:else}
	<p class="text-text-muted">Cargando...</p>
{/if}
