<script lang="ts">
	import Avatar from '$lib/components/ui/avatar/avatar.svelte';
	import Badge from '$lib/components/ui/badge/badge.svelte';
	// TODO: Import Dropdown/Menu primitives for user menu

	// TODO: Replace with real session/project store
	const user = { name: 'Admin User', email: 'admin@example.com' };
	const projects = [
		{ id: 1, name: 'Project Alpha' },
		{ id: 2, name: 'Project Beta' }
	];
	let selectedProject = projects[0];

	// TODO: Replace with real status
	const wsStatus = 'online';
	const backendStatus = 'ok';
</script>

<header
	class="bg-background/80 z-10 flex items-center justify-between border-b px-4 py-2 backdrop-blur"
>
	<div class="flex items-center gap-4">
		<!-- Project Selector (stub) -->
		<select class="bg-background rounded border px-2 py-1">
			{#each projects as project (project.id)}
				<option value={project.id} selected={project.id === selectedProject.id}
					>{project.name}</option
				>
			{/each}
		</select>
		<!-- Live Status Indicators -->
		<Badge variant={wsStatus === 'online' ? 'default' : 'destructive'}>WS: {wsStatus}</Badge>
		<Badge variant={backendStatus === 'ok' ? 'default' : 'destructive'}
			>API: {backendStatus}</Badge
		>
	</div>
	<div class="flex items-center gap-2">
		<!-- User Avatar and Dropdown (stub) -->
		<Avatar />
		<span class="ml-2 font-medium">{user.name}</span>
		<!-- TODO: Add dropdown for profile/logout -->
	</div>
</header>
