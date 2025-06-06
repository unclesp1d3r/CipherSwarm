<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { Button } from '$lib/components/ui/button';

	import {
		Table,
		TableBody,
		TableCell,
		TableHead,
		TableHeader,
		TableRow
	} from '$lib/components/ui/table';
	import { Badge } from '$lib/components/ui/badge';
	import {
		Card,
		CardContent,
		CardDescription,
		CardHeader,
		CardTitle
	} from '$lib/components/ui/card';
	import { Skeleton } from '$lib/components/ui/skeleton';
	import { Alert, AlertDescription } from '$lib/components/ui/alert';
	import { Search, Upload, FileText, Filter } from '@lucide/svelte';

	interface ResourceItem {
		id: string;
		file_name: string;
		resource_type: string;
		line_count: number | null;
		byte_size: number | null;
		updated_at: string | null;
		file_label?: string | null;
		project_id?: number | null;
		unrestricted?: boolean | null;
	}

	interface ResourceListResponse {
		items: ResourceItem[];
		total_count: number;
		page: number;
		page_size: number;
		total_pages: number;
		resource_type?: string | null;
	}

	let resources: ResourceItem[] = [];
	let totalCount = 0;
	let currentPage = 1;
	let pageSize = 25;
	let totalPages = 0;
	let loading = true;
	let error: string | null = null;

	// Filter state
	let searchQuery = '';
	let selectedResourceType = '';
	let filterApplied = false;

	const resourceTypes = [
		{ value: '', label: 'All Types' },
		{ value: 'mask_list', label: 'Mask List' },
		{ value: 'rule_list', label: 'Rule List' },
		{ value: 'word_list', label: 'Word List' },
		{ value: 'charset', label: 'Charset' },
		{ value: 'dynamic_word_list', label: 'Dynamic Word List' }
	];

	// Initialize from URL params
	onMount(() => {
		const urlParams = new URLSearchParams($page.url.search);
		searchQuery = urlParams.get('q') || '';
		selectedResourceType = urlParams.get('resource_type') || '';
		currentPage = parseInt(urlParams.get('page') || '1');
		pageSize = parseInt(urlParams.get('page_size') || '25');

		loadResources();
	});

	async function loadResources() {
		loading = true;
		error = null;

		try {
			const params = new URLSearchParams({
				page: currentPage.toString(),
				page_size: pageSize.toString()
			});

			if (searchQuery.trim()) {
				params.append('q', searchQuery.trim());
			}

			if (selectedResourceType) {
				params.append('resource_type', selectedResourceType);
			}

			const response = await fetch(`/api/v1/web/resources/?${params}`);

			if (!response.ok) {
				throw new Error(
					`Failed to load resources: ${response.status} ${response.statusText}`
				);
			}

			const data: ResourceListResponse = await response.json();
			resources = data.items;
			totalCount = data.total_count;
			totalPages = data.total_pages;
			currentPage = data.page;
			pageSize = data.page_size;
		} catch (err) {
			error = err instanceof Error ? err.message : 'Failed to load resources';
			console.error('Error loading resources:', err);
		} finally {
			loading = false;
		}
	}

	function updateURL() {
		const params = new URLSearchParams();

		if (searchQuery.trim()) params.set('q', searchQuery.trim());
		if (selectedResourceType) params.set('resource_type', selectedResourceType);
		if (currentPage > 1) params.set('page', currentPage.toString());
		if (pageSize !== 25) params.set('page_size', pageSize.toString());

		const newUrl = `/resources${params.toString() ? '?' + params.toString() : ''}`;
		goto(newUrl, { replaceState: true, noScroll: true });
	}

	function handleFilter() {
		currentPage = 1; // Reset to first page when filtering
		filterApplied = !!(searchQuery.trim() || selectedResourceType);
		updateURL();
		loadResources();
	}

	function handlePageChange(newPage: number) {
		currentPage = newPage;
		updateURL();
		loadResources();
	}

	function formatResourceType(type: string): string {
		return type.replace('_', ' ').replace(/\b\w/g, (l) => l.toUpperCase());
	}

	function formatFileSize(bytes: number | null): string {
		if (!bytes) return '0 KB';
		const kb = Math.round(bytes / 1024);
		return `${kb.toLocaleString()} KB`;
	}

	function formatDate(dateStr: string | null): string {
		if (!dateStr) return '';
		return new Date(dateStr).toLocaleDateString('en-US', {
			year: 'numeric',
			month: '2-digit',
			day: '2-digit',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function getResourceTypeVariant(
		type: string
	): 'default' | 'secondary' | 'destructive' | 'outline' {
		switch (type) {
			case 'mask_list':
				return 'default';
			case 'rule_list':
				return 'secondary';
			case 'word_list':
				return 'outline';
			case 'charset':
				return 'destructive';
			case 'dynamic_word_list':
				return 'secondary';
			default:
				return 'outline';
		}
	}
</script>

<svelte:head>
	<title>Resources - CipherSwarm</title>
</svelte:head>

<div class="container mx-auto space-y-6 p-6">
	<div class="flex items-center justify-between">
		<div>
			<h1 class="text-3xl font-bold tracking-tight">Resources</h1>
			<p class="text-muted-foreground">
				Manage wordlists, rule lists, masks, and charsets for password cracking attacks
			</p>
		</div>
		<Button class="gap-2">
			<Upload class="h-4 w-4" />
			Upload Resource
		</Button>
	</div>

	<!-- Filters -->
	<Card>
		<CardHeader>
			<CardTitle class="flex items-center gap-2">
				<Filter class="h-4 w-4" />
				Filters
			</CardTitle>
			<CardDescription>Search and filter resources by type and name</CardDescription>
		</CardHeader>
		<CardContent>
			<div class="flex flex-wrap items-end gap-4">
				<div class="min-w-[200px] flex-1">
					<label for="search" class="mb-2 block text-sm font-medium">Search</label>
					<div class="relative">
						<Search
							class="text-muted-foreground absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 transform"
						/>
						<input
							id="search"
							type="text"
							placeholder="Search resources..."
							bind:value={searchQuery}
							class="form-input w-full rounded border px-2 py-1 pl-10"
							on:keydown={(e) => {
								if (e.key === 'Enter') {
									handleFilter();
								}
							}}
						/>
					</div>
				</div>
				<div class="min-w-[180px]">
					<label for="resource-type" class="mb-2 block text-sm font-medium"
						>Resource Type</label
					>
					<select
						id="resource-type"
						bind:value={selectedResourceType}
						class="bg-background rounded border px-2 py-1"
					>
						{#each resourceTypes as type (type.value)}
							<option value={type.value}>{type.label}</option>
						{/each}
					</select>
				</div>
				<Button onclick={handleFilter} class="gap-2">
					<Search class="h-4 w-4" />
					Filter
				</Button>
				{#if filterApplied}
					<Button
						variant="outline"
						onclick={() => {
							searchQuery = '';
							selectedResourceType = '';
							filterApplied = false;
							handleFilter();
						}}
					>
						Clear
					</Button>
				{/if}
			</div>
		</CardContent>
	</Card>

	<!-- Results -->
	<Card>
		<CardHeader>
			<CardTitle class="flex items-center gap-2">
				<FileText class="h-4 w-4" />
				Resources
				{#if !loading}
					<Badge variant="secondary" data-testid="resource-count">{totalCount}</Badge>
				{/if}
			</CardTitle>
		</CardHeader>
		<CardContent>
			{#if error}
				<Alert variant="destructive">
					<AlertDescription>{error}</AlertDescription>
				</Alert>
			{:else if loading}
				<div class="space-y-3">
					{#each Array(5) as _, i (i)}
						<div class="flex items-center space-x-4">
							<Skeleton class="h-4 w-[250px]" data-testid="skeleton" />
							<Skeleton class="h-4 w-[100px]" />
							<Skeleton class="h-4 w-[80px]" />
							<Skeleton class="h-4 w-[60px]" />
							<Skeleton class="h-4 w-[120px]" />
						</div>
					{/each}
				</div>
			{:else}
				<div class="rounded-md border">
					<Table>
						<TableHeader>
							<TableRow>
								<TableHead>Name</TableHead>
								<TableHead>Type</TableHead>
								<TableHead>Size</TableHead>
								<TableHead>Lines</TableHead>
								<TableHead>Last Updated</TableHead>
							</TableRow>
						</TableHeader>
						<TableBody>
							{#if resources.length === 0}
								<TableRow>
									<TableCell
										colspan={5}
										class="text-muted-foreground py-8 text-center"
									>
										No resources found.
										{#if filterApplied}
											Try adjusting your filters.
										{/if}
									</TableCell>
								</TableRow>
							{:else}
								{#each resources as resource (resource.id)}
									<TableRow class="hover:bg-muted/50">
										<TableCell class="font-mono">
											<a
												href="/api/v1/web/resources/{resource.id}"
												class="text-primary hover:underline"
											>
												{resource.file_name}
											</a>
											{#if resource.file_label}
												<div class="text-muted-foreground mt-1 text-xs">
													{resource.file_label}
												</div>
											{/if}
										</TableCell>
										<TableCell>
											<Badge
												variant={getResourceTypeVariant(
													resource.resource_type
												)}
											>
												{formatResourceType(resource.resource_type)}
											</Badge>
										</TableCell>
										<TableCell>{formatFileSize(resource.byte_size)}</TableCell>
										<TableCell>
											{resource.line_count
												? resource.line_count.toLocaleString()
												: '—'}
										</TableCell>
										<TableCell class="text-muted-foreground">
											{formatDate(resource.updated_at)}
										</TableCell>
									</TableRow>
								{/each}
							{/if}
						</TableBody>
					</Table>
				</div>

				<!-- Pagination -->
				{#if totalPages > 1}
					<div class="mt-4 flex items-center justify-between">
						<div class="text-muted-foreground text-sm">
							Showing {(currentPage - 1) * pageSize + 1} - {Math.min(
								currentPage * pageSize,
								totalCount
							)} of {totalCount} resources
						</div>
						<div class="flex gap-2">
							<Button
								variant="outline"
								size="sm"
								disabled={currentPage <= 1}
								onclick={() => handlePageChange(currentPage - 1)}
							>
								Previous
							</Button>
							<Button
								variant="outline"
								size="sm"
								disabled={currentPage >= totalPages}
								onclick={() => handlePageChange(currentPage + 1)}
							>
								Next
							</Button>
						</div>
					</div>
				{/if}
			{/if}
		</CardContent>
	</Card>
</div>
