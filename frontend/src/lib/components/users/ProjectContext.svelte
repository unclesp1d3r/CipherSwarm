<script lang="ts">
	import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/ui/card';
	import { Button } from '$lib/components/ui/button';
	import { Label } from '$lib/components/ui/label';
	import { Select, SelectContent, SelectItem, SelectTrigger } from '$lib/components/ui/select';
	import { Badge } from '$lib/components/ui/badge';
	import { toast } from '$lib/utils/toast';
	import type { User } from '$lib/types/user';
	import { createEventDispatcher } from 'svelte';

	export let user: User;
	export let activeProject: { id: number; name: string } | null = null;
	export let availableProjects: { id: number; name: string; private?: boolean }[] = [];

	let selectedProjectId: string = activeProject?.id?.toString() || '';
	let isSwitchingProject = false;

	$: selectedProject = availableProjects.find((p) => p.id.toString() === selectedProjectId);

	const dispatch = createEventDispatcher<{
		projectSwitched: { projectId: number };
	}>();

	async function handleProjectSwitch() {
		if (!selectedProjectId || selectedProjectId === activeProject?.id?.toString()) {
			return;
		}

		isSwitchingProject = true;

		try {
			const response = await fetch('/api/v1/web/auth/context', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({
					project_id: parseInt(selectedProjectId)
				})
			});

			if (response.ok) {
				toast.success('Project switched successfully');
				dispatch('projectSwitched', { projectId: parseInt(selectedProjectId) });
			} else {
				const error = await response.json();
				toast.error(error.detail || 'Failed to switch project');
				// Reset selection on error
				selectedProjectId = activeProject?.id?.toString() || '';
			}
		} catch (error) {
			toast.error('Network error occurred');
			// Reset selection on error
			selectedProjectId = activeProject?.id?.toString() || '';
		} finally {
			isSwitchingProject = false;
		}
	}

	function formatRole(role: string): string {
		// Handle underscores and format properly
		return role
			.split('_')
			.map((word) => word.charAt(0).toUpperCase() + word.slice(1))
			.join(' ');
	}
</script>

<Card class="mx-auto max-w-2xl">
	<CardHeader>
		<CardTitle>Project Context</CardTitle>
	</CardHeader>
	<CardContent class="space-y-4">
		<div class="grid grid-cols-1 gap-4 md:grid-cols-2">
			<div class="space-y-2">
				<Label class="text-muted-foreground text-sm font-medium">User</Label>
				<p class="text-sm">{user.email}</p>
			</div>
			<div class="space-y-2">
				<Label class="text-muted-foreground text-sm font-medium">Role</Label>
				<Badge variant="outline">{formatRole(user.role)}</Badge>
			</div>
			<div class="space-y-2">
				<Label class="text-muted-foreground text-sm font-medium">Active Project</Label>
				<p class="text-sm">{activeProject?.name || 'None'}</p>
			</div>
		</div>

		{#if availableProjects.length > 1}
			<div class="space-y-2">
				<Label for="project-select">Switch Project</Label>
				<Select type="single" bind:value={selectedProjectId}>
					<SelectTrigger id="project-select">
						<span>{selectedProject?.name || 'Select a project'}</span>
					</SelectTrigger>
					<SelectContent>
						{#each availableProjects as project (project.id)}
							<SelectItem value={project.id.toString()}>{project.name}</SelectItem>
						{/each}
					</SelectContent>
				</Select>

				<Button
					onclick={handleProjectSwitch}
					disabled={isSwitchingProject ||
						!selectedProjectId ||
						selectedProjectId === activeProject?.id?.toString()}
					class="w-full"
				>
					{isSwitchingProject ? 'Switching...' : 'Set Active Project'}
				</Button>
			</div>
		{:else if availableProjects.length === 1}
			<p class="text-muted-foreground text-sm">You have access to one project only.</p>
		{:else}
			<p class="text-muted-foreground text-sm">
				No projects available. Contact your administrator for access.
			</p>
		{/if}
	</CardContent>
</Card>
