<script lang="ts">
	import { onMount } from 'svelte';
	import axios from 'axios';
	import { Card, CardHeader, CardTitle, CardContent } from '$lib/components/ui/card';
	import {
		Table,
		TableHead,
		TableHeader,
		TableBody,
		TableRow,
		TableCell
	} from '$lib/components/ui/table';
	import { Button } from '$lib/components/ui/button';
	import { Badge } from '$lib/components/ui/badge';
	import { Input } from '$lib/components/ui/input';
	import {
		DropdownMenu,
		DropdownMenuTrigger,
		DropdownMenuContent,
		DropdownMenuItem
	} from '$lib/components/ui/dropdown-menu';
	import { MoreHorizontal, Plus, Archive, Eye, Edit } from '@lucide/svelte';
	import type { Project, ProjectListResponse } from '$lib/types/project';

	let projects: Project[] = [];
	let loading = true;
	let error = '';
	let page = 1;
	let pageSize = 20;
	let total = 0;
	let search = '';
	let searchInput = '';

	async function fetchProjects() {
		loading = true;
		error = '';
		try {
			const params = new URLSearchParams({
				page: page.toString(),
				page_size: pageSize.toString()
			});
			if (search) {
				params.append('search', search);
			}

			const response = await axios.get(`/api/v1/web/projects?${params}`);
			const data: ProjectListResponse = response.data;
			projects = data.items;
			total = data.total;
		} catch (e: unknown) {
			error =
				(e as { response?: { status?: number } }).response?.status === 403
					? 'Access denied. You must be an administrator to view projects.'
					: 'Failed to load projects.';
			projects = [];
			total = 0;
		} finally {
			loading = false;
		}
	}

	onMount(fetchProjects);

	function handleSearch() {
		search = searchInput;
		page = 1;
		fetchProjects();
	}

	function handleKeyDown(event: KeyboardEvent) {
		if (event.key === 'Enter') {
			handleSearch();
		}
	}

	function handlePageChange(newPage: number) {
		page = newPage;
		fetchProjects();
	}

	function formatDate(dateStr: string): string {
		return new Date(dateStr).toLocaleDateString();
	}

	function getStatusBadge(project: Project) {
		if (project.archived_at) {
			return { text: 'Archived', class: 'bg-gray-100 text-gray-800 border-gray-200' };
		}
		return { text: 'Active', class: 'bg-green-100 text-green-800 border-green-200' };
	}

	function getVisibilityBadge(isPrivate: boolean) {
		if (isPrivate) {
			return { text: 'Private', class: 'bg-red-100 text-red-800 border-red-200' };
		}
		return { text: 'Public', class: 'bg-blue-100 text-blue-800 border-blue-200' };
	}

	// Pagination calculations
	$: totalPages = Math.ceil(total / pageSize);
	$: startIndex = (page - 1) * pageSize + 1;
	$: endIndex = Math.min((page - 1) * pageSize + projects.length, total);
</script>

<div class="container mx-auto p-6">
	<Card>
		<CardHeader>
			<div class="flex items-center justify-between">
				<CardTitle data-testid="projects-title">Project Management</CardTitle>
				<Button data-testid="create-project-button">
					<Plus class="mr-2 h-4 w-4" />
					Create Project
				</Button>
			</div>
		</CardHeader>
		<CardContent>
			<!-- Search -->
			<div class="mb-6 flex gap-2">
				<Input
					type="text"
					placeholder="Search projects by name or description..."
					bind:value={searchInput}
					onkeydown={handleKeyDown}
					class="max-w-md"
					data-testid="search-input"
				/>
				<Button onclick={handleSearch} data-testid="search-button">Search</Button>
			</div>

			{#if loading}
				<div class="py-8 text-center" data-testid="loading-state">Loading projects…</div>
			{:else if error}
				<div class="py-8 text-center text-red-600" data-testid="error-message">{error}</div>
			{:else if projects.length === 0}
				<div class="py-8 text-center" data-testid="empty-state">
					{#if search}
						No projects found matching "{search}".
					{:else}
						No projects found. <Button data-testid="empty-state-create-button">
							<Plus class="mr-2 h-4 w-4" />
							Create Project
						</Button>
					{/if}
				</div>
			{:else}
				<!-- Projects Table -->
				<div class="rounded-md border">
					<Table>
						<TableHeader>
							<TableRow>
								<TableHead>Name</TableHead>
								<TableHead>Description</TableHead>
								<TableHead>Visibility</TableHead>
								<TableHead>Status</TableHead>
								<TableHead>Users</TableHead>
								<TableHead>Created</TableHead>
								<TableHead>Updated</TableHead>
								<TableHead class="text-right">Actions</TableHead>
							</TableRow>
						</TableHeader>
						<TableBody>
							{#each projects as project (project.id)}
								<TableRow data-testid="project-row">
									<TableCell class="font-medium" data-testid="project-name">
										{project.name}
									</TableCell>
									<TableCell data-testid="project-description">
										{project.description || '-'}
									</TableCell>
									<TableCell data-testid="project-visibility">
										{@const visibilityBadge = getVisibilityBadge(
											project.private
										)}
										<Badge variant="outline" class={visibilityBadge.class}>
											{visibilityBadge.text}
										</Badge>
									</TableCell>
									<TableCell data-testid="project-status">
										{@const statusBadge = getStatusBadge(project)}
										<Badge variant="outline" class={statusBadge.class}>
											{statusBadge.text}
										</Badge>
									</TableCell>
									<TableCell data-testid="project-user-count"
										>{project.users.length}</TableCell
									>
									<TableCell data-testid="project-created">
										{formatDate(project.created_at)}
									</TableCell>
									<TableCell data-testid="project-updated">
										{formatDate(project.updated_at)}
									</TableCell>
									<TableCell class="text-right">
										<DropdownMenu>
											<DropdownMenuTrigger>
												<Button
													variant="ghost"
													size="sm"
													class="h-8 w-8 p-0"
													data-testid="project-actions-{project.id}"
												>
													<MoreHorizontal class="h-4 w-4" />
													<span class="sr-only">Open menu</span>
												</Button>
											</DropdownMenuTrigger>
											<DropdownMenuContent align="end">
												<DropdownMenuItem
													data-testid="project-view-{project.id}"
												>
													<Eye class="mr-2 h-4 w-4" />
													View Details
												</DropdownMenuItem>
												<DropdownMenuItem
													data-testid="project-edit-{project.id}"
												>
													<Edit class="mr-2 h-4 w-4" />
													Edit Project
												</DropdownMenuItem>
												{#if !project.archived_at}
													<DropdownMenuItem
														data-testid="project-archive-{project.id}"
													>
														<Archive class="mr-2 h-4 w-4" />
														Archive Project
													</DropdownMenuItem>
												{/if}
											</DropdownMenuContent>
										</DropdownMenu>
									</TableCell>
								</TableRow>
							{/each}
						</TableBody>
					</Table>
				</div>

				<!-- Pagination -->
				{#if totalPages > 1}
					<div class="mt-6 flex items-center justify-between">
						<div class="text-muted-foreground text-sm" data-testid="pagination-info">
							Showing {startIndex}-{endIndex} of {total} projects
						</div>
						<div class="flex items-center space-x-2">
							<Button
								variant="outline"
								size="sm"
								onclick={() => handlePageChange(page - 1)}
								disabled={page <= 1}
								data-testid="pagination-prev"
							>
								Previous
							</Button>
							{#if totalPages <= 7}
								{#each Array(totalPages)
									.fill(0)
									.map((_, i) => i + 1) as pageNum (pageNum)}
									<Button
										variant={pageNum === page ? 'default' : 'outline'}
										size="sm"
										onclick={() => handlePageChange(pageNum)}
										data-testid="pagination-page-{pageNum}"
									>
										{pageNum}
									</Button>
								{/each}
							{:else}
								<!-- Show first page -->
								<Button
									variant={1 === page ? 'default' : 'outline'}
									size="sm"
									onclick={() => handlePageChange(1)}
									data-testid="pagination-page-1"
								>
									1
								</Button>

								{#if page > 4}
									<span class="text-muted-foreground text-sm">…</span>
								{/if}

								<!-- Show pages around current page -->
								{#each Array(Math.min(5, totalPages))
									.fill(0)
									.map( (_, i) => Math.max(2, Math.min(totalPages - 1, page - 2 + i)) )
									.filter((p, i, arr) => arr.indexOf(p) === i && p > 1 && p < totalPages) as pageNum (pageNum)}
									<Button
										variant={pageNum === page ? 'default' : 'outline'}
										size="sm"
										onclick={() => handlePageChange(pageNum)}
										data-testid="pagination-page-{pageNum}"
									>
										{pageNum}
									</Button>
								{/each}

								{#if page < totalPages - 3}
									<span class="text-muted-foreground text-sm">…</span>
								{/if}

								<!-- Show last page -->
								{#if totalPages > 1}
									<Button
										variant={totalPages === page ? 'default' : 'outline'}
										size="sm"
										onclick={() => handlePageChange(totalPages)}
										data-testid="pagination-page-{totalPages}"
									>
										{totalPages}
									</Button>
								{/if}
							{/if}
							<Button
								variant="outline"
								size="sm"
								onclick={() => handlePageChange(page + 1)}
								disabled={page >= totalPages}
								data-testid="pagination-next"
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
