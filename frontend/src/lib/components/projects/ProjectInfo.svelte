<script lang="ts">
	import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/ui/card';
	import { Badge } from '$lib/components/ui/badge';
	import type { Project } from '$lib/types/project.js';

	interface Props {
		project: Project;
	}

	let { project }: Props = $props();

	function formatDate(dateString: string | null): string {
		if (!dateString) return '—';
		return new Date(dateString).toLocaleString();
	}

	function formatUserCount(users: string[]): string {
		const count = users?.length || 0;
		return `${count} user${count !== 1 ? 's' : ''}`;
	}
</script>

<Card class="w-full" data-testid="project-info">
	<CardHeader>
		<CardTitle class="flex items-center justify-between">
			<span>Project: {project.name}</span>
			<div class="flex gap-2">
				{#if project.private}
					<Badge variant="secondary">Private</Badge>
				{/if}
				{#if project.archived_at}
					<Badge variant="destructive">Archived</Badge>
				{/if}
			</div>
		</CardTitle>
	</CardHeader>
	<CardContent>
		<dl class="grid grid-cols-1 gap-4 sm:grid-cols-2">
			<div>
				<dt class="text-muted-foreground text-sm font-medium">ID</dt>
				<dd class="text-sm">{project.id}</dd>
			</div>
			<div>
				<dt class="text-muted-foreground text-sm font-medium">Users</dt>
				<dd class="text-sm">{formatUserCount(project.users)}</dd>
			</div>
			<div class="sm:col-span-2">
				<dt class="text-muted-foreground text-sm font-medium">Description</dt>
				<dd class="text-sm">{project.description || '—'}</dd>
			</div>
			{#if project.notes}
				<div class="sm:col-span-2">
					<dt class="text-muted-foreground text-sm font-medium">Notes</dt>
					<dd class="text-sm">{project.notes}</dd>
				</div>
			{/if}
			<div>
				<dt class="text-muted-foreground text-sm font-medium">Created At</dt>
				<dd class="text-sm">{formatDate(project.created_at)}</dd>
			</div>
			<div>
				<dt class="text-muted-foreground text-sm font-medium">Updated At</dt>
				<dd class="text-sm">{formatDate(project.updated_at)}</dd>
			</div>
			{#if project.archived_at}
				<div class="sm:col-span-2">
					<dt class="text-muted-foreground text-sm font-medium">Archived At</dt>
					<dd class="text-sm">{formatDate(project.archived_at)}</dd>
				</div>
			{/if}
		</dl>
	</CardContent>
</Card>
