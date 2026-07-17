<script lang="ts">
	import { createEventDispatcher } from 'svelte';

	export let page: number;
	export let totalPages: number;

	const dispatch = createEventDispatcher<{ navigate: number }>();

	function goTo(p: number) {
		if (p >= 1 && p <= totalPages && p !== page) {
			dispatch('navigate', p);
		}
	}
</script>

{#if totalPages > 1}
	<div class="flex items-center justify-center gap-2 py-4 text-sm">
		<button
			class="px-3 py-1 rounded border border-gray-300 bg-white text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
			disabled={page <= 1}
			on:click={() => goTo(page - 1)}
		>
			← Anterior
		</button>

		<span class="px-3 py-1 text-gray-600">
			Página {page} de {totalPages}
		</span>

		<button
			class="px-3 py-1 rounded border border-gray-300 bg-white text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
			disabled={page >= totalPages}
			on:click={() => goTo(page + 1)}
		>
			Siguiente →
		</button>
	</div>
{/if}
