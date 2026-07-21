<script lang="ts">
	import '../app.css';
</script>

<div class="min-h-screen flex flex-col">
	<header class="flex items-center gap-8 px-6 py-3 bg-surface border-b border-border">
		<a href="/" class="font-bold text-lg text-primary no-underline">Mesa de Entradas</a>
		<nav class="flex gap-6">
			<a href="/dashboard" class="text-text no-underline hover:underline">Dashboard</a>
			<a href="/expedientes" class="text-text no-underline hover:underline">Expedientes</a>
			<a href="/reclamos" class="text-text no-underline hover:underline">Reclamos</a>
			<a href="/notificaciones" class="text-text no-underline hover:underline">Notificaciones</a>
		</nav>
	</header>

	<main class="w-full max-w-5xl mx-auto p-6">
		<slot />
	</main>
</div>
