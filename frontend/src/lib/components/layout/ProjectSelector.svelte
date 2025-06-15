<script lang="ts">
	import { projectsStore } from '$lib/stores/projects.svelte';

	// Get project context from store
	const activeProject = $derived(projectsStore.activeProject);
	const availableProjects = $derived(projectsStore.availableProjects);
	const user = $derived(projectsStore.contextUser);

	// Local state for selection
	let selectedProjectId = $state('');

	// Sync selected project with active project from store
	$effect(() => {
		if (activeProject) {
			selectedProjectId = activeProject.id.toString();
		}
	});

	// Handle project change
	function handleProjectChange(event: Event) {
		const target = event.target as HTMLSelectElement;
		const newProjectId = parseInt(target.value);

		// Find the selected project
		const newProject = availableProjects.find((p) => p.id === newProjectId);
		if (newProject) {
			// Update the store - this would typically trigger an API call
			projectsStore.setActiveProject(newProject);
		}
	}

	// TODO: Replace with real status from appropriate stores
	const wsStatus = 'online';
	const backendStatus = 'ok';
</script>

{#if availableProjects.length > 0}
	<select
		class="bg-background rounded border px-2 py-1"
		bind:value={selectedProjectId}
		onchange={handleProjectChange}
	>
		{#each availableProjects as project (project.id)}
			<option value={project.id.toString()}>
				{project.name}
			</option>
		{/each}
	</select>
{:else}
	<div class="bg-background text-muted-foreground rounded border px-2 py-1 text-sm">
		No projects available
	</div>
{/if}
