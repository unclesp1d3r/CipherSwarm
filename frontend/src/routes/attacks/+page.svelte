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
	import { Alert, AlertDescription } from '$lib/components/ui/alert';
	import { Skeleton } from '$lib/components/ui/skeleton';
	import AttackEditorModal from '$lib/components/attacks/AttackEditorModal.svelte';
	import AttackViewModal from '$lib/components/attacks/AttackViewModal.svelte';
	import MoreHorizontalIcon from '@lucide/svelte/icons/more-horizontal';
	import PlusIcon from '@lucide/svelte/icons/plus';
	import SearchIcon from '@lucide/svelte/icons/search';

	interface Attack {
		id: number;
		name: string;
		type: string;
		language?: string;
		length_min?: number;
		length_max?: number;
		settings_summary?: string;
		keyspace?: number;
		complexity_score?: number;
		comment?: string;
		state: string;
		created_at: string;
		updated_at: string;
		campaign_id?: number;
		campaign_name?: string;
		[key: string]: unknown;
	}

	interface AttacksResponse {
		attacks: Attack[];
		total: number;
		page: number;
		size: number;
		total_pages: number;
	}

	let attacks: Attack[] = [];
	let loading = true;
	let error = '';
	let searchQuery = '';
	let page = 1;
	let size = 10;
	let total = 0;
	let totalPages = 0;

	// Debounce search
	let searchTimeout: ReturnType<typeof setTimeout>;

	async function fetchAttacks() {
		loading = true;
		error = '';
		try {
			const params = new URLSearchParams({
				page: page.toString(),
				size: size.toString()
			});

			if (searchQuery.trim()) {
				params.set('q', searchQuery.trim());
			}

			const response = await axios.get(`/api/v1/web/attacks?${params}`);
			const data: AttacksResponse = response.data;

			attacks = data.attacks;
			total = data.total;
			totalPages = data.total_pages;
		} catch (e) {
			error = 'Failed to load attacks.';
			attacks = [];
		} finally {
			loading = false;
		}
	}

	function handleSearch(event: Event) {
		const target = event.target as HTMLInputElement;
		searchQuery = target.value;

		clearTimeout(searchTimeout);
		searchTimeout = setTimeout(() => {
			page = 1; // Reset to first page when searching
			fetchAttacks();
		}, 300);
	}

	function handlePageChange(newPage: number) {
		page = newPage;
		fetchAttacks();
	}

	function getAttackTypeBadge(type: string) {
		switch (type) {
			case 'dictionary':
				return { color: 'bg-blue-500 text-white', label: 'Dictionary' };
			case 'mask':
				return { color: 'bg-purple-500 text-white', label: 'Mask' };
			case 'brute_force':
				return { color: 'bg-orange-500 text-white', label: 'Brute Force' };
			case 'hybrid_dictionary':
				return { color: 'bg-teal-500 text-white', label: 'Hybrid Dictionary' };
			case 'hybrid_mask':
				return { color: 'bg-pink-500 text-white', label: 'Hybrid Mask' };
			default:
				return {
					color: 'bg-gray-400 text-white',
					label: type.replace('_', ' ').toUpperCase()
				};
		}
	}

	function getStateBadge(state: string) {
		switch (state) {
			case 'running':
				return { color: 'bg-green-600 text-white', label: 'Running' };
			case 'completed':
				return { color: 'bg-blue-600 text-white', label: 'Completed' };
			case 'error':
				return { color: 'bg-red-600 text-white', label: 'Error' };
			case 'paused':
				return { color: 'bg-yellow-500 text-white', label: 'Paused' };
			case 'draft':
				return { color: 'bg-gray-400 text-white', label: 'Draft' };
			default:
				return {
					color: 'bg-gray-200 text-gray-800',
					label: state.replace('_', ' ').toUpperCase()
				};
		}
	}

	function formatLength(minLength?: number, maxLength?: number): string {
		if (minLength === undefined && maxLength === undefined) return '—';
		if (minLength === maxLength) return String(minLength);
		return `${minLength || 0} → ${maxLength || 0}`;
	}

	function formatKeyspace(keyspace?: number): string {
		if (!keyspace) return '—';
		return keyspace.toLocaleString();
	}

	function renderComplexityDots(score?: number): { filled: number; total: number } {
		const complexityScore = score || 0;
		return { filled: complexityScore, total: 5 };
	}

	// Modal state
	let showEditorModal = false;
	let showViewModal = false;
	let selectedAttack: Attack | null = null;

	async function handleNewAttack() {
		selectedAttack = null;
		showEditorModal = true;
	}

	async function handleEditAttack(attackId: number) {
		const attack = attacks.find((a) => a.id === attackId);
		if (attack) {
			selectedAttack = attack;
			showEditorModal = true;
		}
	}

	async function handleViewAttack(attackId: number) {
		const attack = attacks.find((a) => a.id === attackId);
		if (attack) {
			selectedAttack = attack;
			showViewModal = true;
		}
	}

	function handleEditorSuccess() {
		showEditorModal = false;
		selectedAttack = null;
		fetchAttacks(); // Refresh data
	}

	function handleEditorCancel() {
		showEditorModal = false;
		selectedAttack = null;
	}

	function handleViewClose() {
		showViewModal = false;
		selectedAttack = null;
	}

	async function handleDuplicateAttack(attackId: number) {
		try {
			await axios.post(`/api/v1/web/attacks/${attackId}/duplicate`);
			await fetchAttacks(); // Refresh data
		} catch (e) {
			error = 'Failed to duplicate attack.';
		}
	}

	async function handleDeleteAttack(attackId: number) {
		if (confirm('Are you sure you want to delete this attack?')) {
			try {
				await axios.delete(`/api/v1/web/attacks/${attackId}`);
				await fetchAttacks(); // Refresh data
			} catch (e) {
				error = 'Failed to delete attack.';
			}
		}
	}

	onMount(fetchAttacks);
</script>

<svelte:head>
	<title>Attacks - CipherSwarm</title>
</svelte:head>

<div class="container mx-auto max-w-7xl p-6">
	<!-- Header -->
	<div class="mb-6">
		<div class="flex items-center justify-between">
			<div>
				<h1 class="text-3xl font-bold tracking-tight">Attacks</h1>
				<p class="text-muted-foreground mt-2">
					Manage and monitor attack configurations across all campaigns
				</p>
			</div>
			<Button onclick={handleNewAttack} data-testid="new-attack-button">
				<PlusIcon class="mr-2 h-4 w-4" />
				New Attack
			</Button>
		</div>
	</div>

	<!-- Search Bar -->
	<Card class="mb-6">
		<CardContent class="pt-6">
			<div class="relative">
				<SearchIcon
					class="text-muted-foreground absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2"
				/>
				<Input
					type="text"
					placeholder="Search attacks by name, type, or settings..."
					class="pl-10"
					value={searchQuery}
					oninput={handleSearch}
					data-testid="search-input"
				/>
			</div>
		</CardContent>
	</Card>

	<!-- Error Alert -->
	{#if error}
		<Alert class="mb-6" variant="destructive" data-testid="error-alert">
			<AlertDescription>{error}</AlertDescription>
		</Alert>
	{/if}

	<!-- Attacks Table -->
	<Card>
		<CardHeader>
			<CardTitle>
				Attacks
				{#if !loading && total > 0}
					<span class="text-muted-foreground ml-2 text-sm font-normal">
						({total.toLocaleString()} total)
					</span>
				{/if}
			</CardTitle>
		</CardHeader>
		<CardContent>
			{#if loading}
				<!-- Loading skeleton -->
				<div class="space-y-3" data-testid="loading-skeleton">
					{#each Array(5) as _, i (i)}
						<div class="flex space-x-4">
							<Skeleton class="h-4 w-[100px]" />
							<Skeleton class="h-4 w-[80px]" />
							<Skeleton class="h-4 w-[60px]" />
							<Skeleton class="h-4 w-[120px]" />
							<Skeleton class="h-4 w-[80px]" />
							<Skeleton class="h-4 w-[60px]" />
							<Skeleton class="h-4 w-[100px]" />
							<Skeleton class="h-4 w-[40px]" />
						</div>
					{/each}
				</div>
			{:else if attacks.length === 0}
				<!-- Empty state -->
				<div class="text-muted-foreground py-8 text-center" data-testid="empty-state">
					{#if searchQuery}
						<p>No attacks found matching "{searchQuery}".</p>
						<Button
							variant="link"
							onclick={() => {
								searchQuery = '';
								page = 1;
								fetchAttacks();
							}}
							class="mt-2"
						>
							Clear search
						</Button>
					{:else}
						<p>No attacks configured yet.</p>
						<Button onclick={handleNewAttack} class="mt-4">
							<PlusIcon class="mr-2 h-4 w-4" />
							Create your first attack
						</Button>
					{/if}
				</div>
			{:else}
				<!-- Attacks table -->
				<Table data-testid="attacks-table">
					<TableHead>
						<TableRow>
							<TableHeader>Name</TableHeader>
							<TableHeader>Type</TableHeader>
							<TableHeader>State</TableHeader>
							<TableHeader>Language</TableHeader>
							<TableHeader>Length</TableHeader>
							<TableHeader>Settings</TableHeader>
							<TableHeader>Keyspace</TableHeader>
							<TableHeader>Complexity</TableHeader>
							<TableHeader>Campaign</TableHeader>
							<TableHeader class="w-16"></TableHeader>
						</TableRow>
					</TableHead>
					<TableBody>
						{#each attacks as attack (attack.id)}
							<TableRow data-testid="attack-row-{attack.id}">
								<TableCell class="font-medium">
									{attack.name}
									{#if attack.comment}
										<div class="text-muted-foreground mt-1 text-xs">
											{attack.comment}
										</div>
									{/if}
								</TableCell>
								<TableCell>
									<Badge
										class={getAttackTypeBadge(
											(attack.attack_mode as string) ||
												(attack.type as string) ||
												''
										).color}
									>
										{getAttackTypeBadge(
											(attack.attack_mode as string) ||
												(attack.type as string) ||
												''
										).label}
									</Badge>
								</TableCell>
								<TableCell>
									<Badge class={getStateBadge(attack.state).color}>
										{getStateBadge(attack.state).label}
									</Badge>
								</TableCell>
								<TableCell>{attack.language || '—'}</TableCell>
								<TableCell>
									{formatLength(
										(attack.min_length as number) ||
											(attack.length_min as number),
										(attack.max_length as number) ||
											(attack.length_max as number)
									)}
								</TableCell>
								<TableCell>
									{#if attack.settings_summary}
										<span
											class="cursor-help text-sm text-blue-600 hover:underline"
											title={attack.settings_summary}
											data-testid="settings-summary-{attack.id}"
										>
											{attack.settings_summary.length > 30
												? attack.settings_summary.substring(0, 30) + '...'
												: attack.settings_summary}
										</span>
									{:else}
										—
									{/if}
								</TableCell>
								<TableCell>{formatKeyspace(attack.keyspace)}</TableCell>
								<TableCell>
									{#if attack.complexity_score}
										<div
											class="flex space-x-1"
											title="Complexity: {attack.complexity_score}/5"
											data-testid="complexity-{attack.id}"
										>
											{#each Array(5) as _, i (i)}
												<span
													class={i < attack.complexity_score
														? 'h-2 w-2 rounded-full bg-gray-600'
														: 'h-2 w-2 rounded-full bg-gray-200'}
												></span>
											{/each}
										</div>
									{:else}
										—
									{/if}
								</TableCell>
								<TableCell>
									{#if attack.campaign_name}
										<span
											class="cursor-pointer text-sm text-blue-600 hover:underline"
										>
											{attack.campaign_name}
										</span>
									{:else}
										<span class="text-muted-foreground">—</span>
									{/if}
								</TableCell>
								<TableCell>
									<DropdownMenu>
										<DropdownMenuTrigger>
											<Button
												variant="ghost"
												size="icon"
												data-testid="attack-menu-{attack.id}"
											>
												<MoreHorizontalIcon class="h-4 w-4" />
												<span class="sr-only">Open menu</span>
											</Button>
										</DropdownMenuTrigger>
										<DropdownMenuContent align="end">
											<DropdownMenuItem
												onclick={() => handleViewAttack(attack.id)}
											>
												View Details
											</DropdownMenuItem>
											<DropdownMenuItem
												onclick={() => handleEditAttack(attack.id)}
											>
												Edit
											</DropdownMenuItem>
											<DropdownMenuItem
												onclick={() => handleDuplicateAttack(attack.id)}
											>
												Duplicate
											</DropdownMenuItem>
											<DropdownMenuItem
												onclick={() => handleDeleteAttack(attack.id)}
												class="text-red-600"
											>
												Delete
											</DropdownMenuItem>
										</DropdownMenuContent>
									</DropdownMenu>
								</TableCell>
							</TableRow>
						{/each}
					</TableBody>
				</Table>

				<!-- Pagination -->
				{#if totalPages > 1}
					<div class="mt-6 flex items-center justify-between">
						<div class="text-muted-foreground text-sm">
							Showing page {page} of {totalPages} ({total.toLocaleString()} total)
						</div>
						<div class="flex space-x-2">
							<Button
								variant="outline"
								onclick={() => handlePageChange(page - 1)}
								disabled={page <= 1}
								data-testid="prev-page"
							>
								Previous
							</Button>
							<Button
								variant="outline"
								onclick={() => handlePageChange(page + 1)}
								disabled={page >= totalPages}
								data-testid="next-page"
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

<!-- Modals -->
<AttackEditorModal
	bind:open={showEditorModal}
	attack={selectedAttack}
	on:success={handleEditorSuccess}
	on:cancel={handleEditorCancel}
/>

<AttackViewModal bind:open={showViewModal} attack={selectedAttack} on:close={handleViewClose} />
