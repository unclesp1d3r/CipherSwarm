<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { Button } from '$lib/components/ui/button';
	import { Tabs, TabsContent, TabsList, TabsTrigger } from '$lib/components/ui/tabs';
	import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/ui/card';
	import { Alert, AlertDescription } from '$lib/components/ui/alert';
	import { ArrowLeft, Download, Edit, Trash2 } from '@lucide/svelte';
	import { goto } from '$app/navigation';

	// Import our resource components
	import ResourceDetail from '$lib/components/resources/ResourceDetail.svelte';
	import ResourcePreview from '$lib/components/resources/ResourcePreview.svelte';
	import ResourceContent from '$lib/components/resources/ResourceContent.svelte';
	import ResourceLines from '$lib/components/resources/ResourceLines.svelte';

	interface Attack {
		id: string;
		name: string;
		campaign_id: string;
		state: string;
	}

	interface Resource {
		id: string;
		file_name: string;
		resource_type: string;
		byte_size: number | null;
		line_count: number | null;
		checksum: string;
		guid: string;
		updated_at: string;
		file_label?: string | null;
		project_id?: number | null;
		unrestricted?: boolean | null;
	}

	interface ResourceLine {
		id: string;
		index: number;
		content: string;
		valid: boolean;
		error_message?: string;
	}

	let resource: Resource | null = null;
	let attacks: Attack[] = [];
	let previewLines: string[] = [];
	let content = '';
	let lines: ResourceLine[] = [];
	let loading = true;
	let error: string | null = null;
	let saving = false;
	let activeTab = 'overview';

	const resourceId = $page.params.id;

	onMount(() => {
		loadResourceDetail();
	});

	async function loadResourceDetail() {
		loading = true;
		error = null;

		try {
			const response = await fetch(`/api/v1/web/resources/${resourceId}`);

			if (!response.ok) {
				throw new Error(
					`Failed to load resource: ${response.status} ${response.statusText}`
				);
			}

			const data = await response.json();
			resource = data;
			attacks = data.attacks || [];

			// Load preview data
			await loadPreview();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to load resource';
			console.error('Error loading resource:', err);
		} finally {
			loading = false;
		}
	}

	async function loadPreview() {
		if (!resource) return;

		try {
			const response = await fetch(`/api/v1/web/resources/${resourceId}/preview`);
			if (response.ok) {
				const data = await response.json();
				previewLines = data.lines || [];
			}
		} catch (err) {
			console.error('Error loading preview:', err);
		}
	}

	async function loadContent() {
		if (!resource) return;

		try {
			const response = await fetch(`/api/v1/web/resources/${resourceId}/content`);
			if (response.ok) {
				const data = await response.json();
				content = data.content || '';
			}
		} catch (err) {
			console.error('Error loading content:', err);
		}
	}

	async function loadLines() {
		if (!resource) return;

		try {
			const response = await fetch(`/api/v1/web/resources/${resourceId}/lines`);
			if (response.ok) {
				const data = await response.json();
				lines = data.lines || [];
			}
		} catch (err) {
			console.error('Error loading lines:', err);
		}
	}

	async function handleSaveContent(event: CustomEvent<{ content: string }>) {
		if (!resource) return;

		saving = true;
		try {
			const response = await fetch(`/api/v1/web/resources/${resourceId}/content`, {
				method: 'PUT',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ content: event.detail.content })
			});

			if (!response.ok) {
				throw new Error(
					`Failed to save content: ${response.status} ${response.statusText}`
				);
			}

			content = event.detail.content;
			// Reload resource detail to get updated metadata
			await loadResourceDetail();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to save content';
			console.error('Error saving content:', err);
		} finally {
			saving = false;
		}
	}

	function handleTabChange(value: string) {
		activeTab = value;

		// Load data for the active tab if not already loaded
		if (value === 'content' && !content) {
			loadContent();
		} else if (value === 'lines' && lines.length === 0) {
			loadLines();
		}
	}

	function isEditable(resource: Resource | null): boolean {
		if (!resource) return false;
		// Files under 1MB are editable
		return (resource.byte_size || 0) < 1024 * 1024;
	}
</script>

<svelte:head>
	<title>Resource: {resource?.file_name || 'Loading...'} - CipherSwarm</title>
</svelte:head>

<div class="container mx-auto space-y-6 p-6">
	<!-- Header -->
	<div class="flex items-center justify-between">
		<div class="flex items-center gap-4">
			<Button variant="ghost" size="sm" onclick={() => goto('/resources')} class="gap-2">
				<ArrowLeft class="h-4 w-4" />
				Back to Resources
			</Button>
			{#if resource}
				<div>
					<h1 class="text-3xl font-bold tracking-tight">{resource.file_name}</h1>
					<p class="text-muted-foreground">Resource details and content management</p>
				</div>
			{/if}
		</div>
		{#if resource}
			<div class="flex items-center gap-2">
				<Button variant="outline" size="sm" class="gap-2">
					<Download class="h-4 w-4" />
					Download
				</Button>
				{#if isEditable(resource)}
					<Button variant="outline" size="sm" class="gap-2">
						<Edit class="h-4 w-4" />
						Edit
					</Button>
				{/if}
				<Button variant="destructive" size="sm" class="gap-2">
					<Trash2 class="h-4 w-4" />
					Delete
				</Button>
			</div>
		{/if}
	</div>

	{#if error}
		<Alert variant="destructive">
			<AlertDescription>{error}</AlertDescription>
		</Alert>
	{/if}

	<!-- Main Content -->
	<Tabs value={activeTab} onValueChange={handleTabChange}>
		<TabsList class="grid w-full grid-cols-4">
			<TabsTrigger value="overview">Overview</TabsTrigger>
			<TabsTrigger value="preview">Preview</TabsTrigger>
			<TabsTrigger value="content" disabled={!isEditable(resource)}>Edit Content</TabsTrigger>
			<TabsTrigger value="lines">Lines</TabsTrigger>
		</TabsList>

		<TabsContent value="overview" class="space-y-6">
			<ResourceDetail {resource} {attacks} {loading} {error} />
		</TabsContent>

		<TabsContent value="preview" class="space-y-6">
			<ResourcePreview
				{resource}
				{previewLines}
				loading={loading && activeTab === 'preview'}
			/>
		</TabsContent>

		<TabsContent value="content" class="space-y-6">
			{#if isEditable(resource)}
				<ResourceContent
					{resource}
					{content}
					{saving}
					loading={loading && activeTab === 'content'}
					on:save={handleSaveContent}
				/>
			{:else}
				<Card>
					<CardHeader>
						<CardTitle>Content Editing Not Available</CardTitle>
					</CardHeader>
					<CardContent>
						<p class="text-muted-foreground">
							This file is too large to edit inline. Files must be under 1MB to enable
							editing.
						</p>
					</CardContent>
				</Card>
			{/if}
		</TabsContent>

		<TabsContent value="lines" class="space-y-6">
			<ResourceLines {resource} {lines} loading={loading && activeTab === 'lines'} />
		</TabsContent>
	</Tabs>
</div>
