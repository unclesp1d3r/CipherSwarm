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
	import UserCreateModal from '$lib/components/users/UserCreateModal.svelte';
	import UserDeleteModal from '$lib/components/users/UserDeleteModal.svelte';
	import UserDetailModal from '$lib/components/users/UserDetailModal.svelte';
	import type { User } from '$lib/types/user';

	let users: User[] = [];
	let loading = true;
	let error = '';
	let page = 1;
	let pageSize = 20;
	let total = 0;
	let search = '';
	let searchInput = '';

	// Modal state
	let showCreateModal = false;
	let showDeleteModal = false;
	let showDetailModal = false;
	let selectedUser: User | null = null;

	async function fetchUsers() {
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

			const response = await axios.get(`/api/v1/web/users?${params}`);
			users = response.data.items;
			total = response.data.total;
		} catch (e: unknown) {
			error =
				(e as { response?: { status?: number } }).response?.status === 403
					? 'Access denied. You must be an administrator to view users.'
					: 'Failed to load users.';
			users = [];
			total = 0;
		} finally {
			loading = false;
		}
	}

	onMount(fetchUsers);

	function handleSearch() {
		search = searchInput;
		page = 1;
		fetchUsers();
	}

	function handleKeyDown(event: KeyboardEvent) {
		if (event.key === 'Enter') {
			handleSearch();
		}
	}

	function handlePageChange(newPage: number) {
		page = newPage;
		fetchUsers();
	}

	function openCreateModal() {
		showCreateModal = true;
	}

	function openDetailModal(user: User) {
		selectedUser = user;
		showDetailModal = true;
	}

	function openDeleteModal(user: User) {
		selectedUser = user;
		showDeleteModal = true;
	}

	function closeCreateModal() {
		showCreateModal = false;
	}

	function closeDetailModal() {
		showDetailModal = false;
		selectedUser = null;
	}

	function closeDeleteModal() {
		showDeleteModal = false;
		selectedUser = null;
	}

	function handleUserCreated() {
		closeCreateModal();
		fetchUsers();
	}

	function handleUserUpdated() {
		closeDetailModal();
		fetchUsers();
	}

	function handleUserDeleted() {
		closeDeleteModal();
		fetchUsers();
	}

	function formatDate(dateStr: string): string {
		return new Date(dateStr).toLocaleDateString();
	}

	function getRoleBadgeColor(role: string): string {
		switch (role.toLowerCase()) {
			case 'admin':
				return 'bg-red-100 text-red-800 border-red-200';
			case 'analyst':
				return 'bg-blue-100 text-blue-800 border-blue-200';
			case 'operator':
				return 'bg-green-100 text-green-800 border-green-200';
			default:
				return 'bg-gray-100 text-gray-800 border-gray-200';
		}
	}

	// Pagination calculations
	$: totalPages = Math.ceil(total / pageSize);
	$: startIndex = (page - 1) * pageSize + 1;
	$: endIndex = Math.min(page * pageSize, total);
</script>

<div class="container mx-auto p-6">
	<Card>
		<CardHeader>
			<div class="flex items-center justify-between">
				<CardTitle data-testid="users-title">User Management</CardTitle>
				<Button data-testid="create-user-button" onclick={openCreateModal}>
					Create User
				</Button>
			</div>
		</CardHeader>
		<CardContent>
			<!-- Search -->
			<div class="mb-6 flex gap-2">
				<Input
					type="text"
					placeholder="Search users by name or email..."
					bind:value={searchInput}
					onkeydown={handleKeyDown}
					class="max-w-md"
					data-testid="search-input"
				/>
				<Button onclick={handleSearch} data-testid="search-button">Search</Button>
			</div>

			{#if loading}
				<div class="py-8 text-center">Loading users…</div>
			{:else if error}
				<div class="py-8 text-center text-red-600" data-testid="error-message">{error}</div>
			{:else if users.length === 0}
				<div class="py-8 text-center" data-testid="empty-state">
					{#if search}
						No users found matching "{search}".
					{:else}
						No users found. <Button
							data-testid="empty-state-create-button"
							onclick={openCreateModal}>Create User</Button
						>
					{/if}
				</div>
			{:else}
				<!-- Users Table -->
				<div class="rounded-md border">
					<Table>
						<TableHeader>
							<TableRow>
								<TableHead>Name</TableHead>
								<TableHead>Email</TableHead>
								<TableHead>Active</TableHead>
								<TableHead>Role</TableHead>
								<TableHead>Created</TableHead>
								<TableHead class="text-right">Actions</TableHead>
							</TableRow>
						</TableHeader>
						<TableBody>
							{#each users as user (user.id)}
								<TableRow data-testid="user-row-{user.id}">
									<TableCell class="font-medium">{user.name}</TableCell>
									<TableCell>{user.email}</TableCell>
									<TableCell>
										<Badge
											class={user.is_active
												? 'border-green-200 bg-green-100 text-green-800'
												: 'border-red-200 bg-red-100 text-red-800'}
										>
											{user.is_active ? 'Yes' : 'No'}
										</Badge>
									</TableCell>
									<TableCell>
										<Badge class={getRoleBadgeColor(user.role)}>
											{user.role.charAt(0).toUpperCase() + user.role.slice(1)}
										</Badge>
									</TableCell>
									<TableCell>{formatDate(user.created_at)}</TableCell>
									<TableCell class="text-right">
										<DropdownMenu>
											<DropdownMenuTrigger>
												<Button
													size="sm"
													variant="ghost"
													data-testid="user-menu-{user.id}"
												>
													<svg
														xmlns="http://www.w3.org/2000/svg"
														width="16"
														height="16"
														viewBox="0 0 24 24"
														fill="none"
														stroke="currentColor"
														stroke-width="2"
														stroke-linecap="round"
														stroke-linejoin="round"
													>
														<circle cx="12" cy="12" r="1"></circle>
														<circle cx="12" cy="5" r="1"></circle>
														<circle cx="12" cy="19" r="1"></circle>
													</svg>
												</Button>
											</DropdownMenuTrigger>
											<DropdownMenuContent>
												<DropdownMenuItem
													onclick={() => openDetailModal(user)}
													data-testid="view-user-{user.id}"
												>
													View Details
												</DropdownMenuItem>
												<DropdownMenuItem
													onclick={() => openDeleteModal(user)}
													data-testid="delete-user-{user.id}"
													class="text-red-600"
												>
													Deactivate
												</DropdownMenuItem>
											</DropdownMenuContent>
										</DropdownMenu>
									</TableCell>
								</TableRow>
							{/each}
						</TableBody>
					</Table>
				</div>

				<!-- Pagination -->
				<div class="mt-6 flex items-center justify-between">
					<div class="text-sm text-gray-700" data-testid="pagination-info">
						Showing {startIndex}-{endIndex} of {total} users
					</div>
					<div class="flex gap-2">
						<Button
							size="sm"
							variant="outline"
							onclick={() => handlePageChange(1)}
							disabled={page === 1}
							data-testid="first-page-button"
						>
							First
						</Button>
						<Button
							size="sm"
							variant="outline"
							onclick={() => handlePageChange(page - 1)}
							disabled={page === 1}
							data-testid="prev-page-button"
						>
							Previous
						</Button>
						<span class="flex items-center px-3 text-sm">
							Page {page} of {totalPages}
						</span>
						<Button
							size="sm"
							variant="outline"
							onclick={() => handlePageChange(page + 1)}
							disabled={page >= totalPages}
							data-testid="next-page-button"
						>
							Next
						</Button>
						<Button
							size="sm"
							variant="outline"
							onclick={() => handlePageChange(totalPages)}
							disabled={page >= totalPages}
							data-testid="last-page-button"
						>
							Last
						</Button>
					</div>
				</div>
			{/if}
		</CardContent>
	</Card>
</div>

<!-- Modals -->
{#if showCreateModal}
	<UserCreateModal onClose={closeCreateModal} onUserCreated={handleUserCreated} />
{/if}

{#if showDetailModal && selectedUser}
	<UserDetailModal
		user={selectedUser}
		onClose={closeDetailModal}
		onUserUpdated={handleUserUpdated}
	/>
{/if}

{#if showDeleteModal && selectedUser}
	<UserDeleteModal
		user={selectedUser}
		onClose={closeDeleteModal}
		onUserDeleted={handleUserDeleted}
	/>
{/if}
