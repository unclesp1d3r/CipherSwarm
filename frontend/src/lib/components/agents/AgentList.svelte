<script context="module" lang="ts">
	// Define the agent type for the list
	export interface AgentListItem {
		id: number;
		host_name: string;
		operating_system: string;
		state: string;
		temperature: number | null;
		utilization: number | null;
		current_attempts_sec: number;
		avg_attempts_sec: number;
		current_job: string;
	}
</script>

<script lang="ts">
	import { onMount } from 'svelte';
	import { writable } from 'svelte/store';
	import Table from '$lib/components/ui/table/table.svelte';
	import TableHeader from '$lib/components/ui/table/table-header.svelte';
	import TableHead from '$lib/components/ui/table/table-head.svelte';
	import TableBody from '$lib/components/ui/table/table-body.svelte';
	import TableRow from '$lib/components/ui/table/table-row.svelte';
	import TableCell from '$lib/components/ui/table/table-cell.svelte';
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import * as Pagination from '$lib/components/ui/pagination/index.js';
	import { Root as Dialog, Content as DialogContent } from '$lib/components/ui/dialog/index.js';
	import { Button } from '$lib/components/ui/button/index.js';
	import { CogIcon } from '@lucide/svelte';
	import AgentDetailsModal from './AgentDetailsModal.svelte';
	import { superForm } from 'sveltekit-superforms';
	import { z } from 'zod';
	import { zodClient } from 'sveltekit-superforms/adapters';

	// Admin role stub (replace with real session store)
	const isAdmin = true;

	// Table state
	const agents = writable<AgentListItem[]>([]);
	const loading = writable(true);
	const error = writable('');
	const page = writable(1);
	const pageSize = 10;
	const total = writable(0);
	const search = writable('');
	const selectedAgent = writable<AgentListItem | null>(null);
	const showModal = writable(false);

	const agentFormSchema = z.object({
		gpuEnabled: z.boolean(),
		cpuEnabled: z.boolean(),
		updateInterval: z.number().min(1, 'Must be at least 1 second').max(3600)
	});

	const agentDetailsFormStore = writable<unknown>(null);

	// Fetch agents from API
	async function fetchAgents(pageNum = 1, searchTerm = '') {
		loading.set(true);
		error.set('');
		try {
			const params = new URLSearchParams({
				page: String(pageNum),
				page_size: String(pageSize)
			});
			if (searchTerm) params.append('search', searchTerm);
			const res = await fetch(`/api/v1/web/agents?${params.toString()}`);
			if (!res.ok) throw new Error('Failed to fetch agents');
			const data = await res.json();
			agents.set(data.items || []);
			total.set(data.total || 0);
		} catch (e) {
			// Fallback to mock data for offline/dev mode
			const mock: AgentListItem[] = [
				{
					id: 1,
					host_name: 'dev-agent-1',
					operating_system: 'linux',
					state: 'active',
					temperature: 55,
					utilization: 0.85,
					current_attempts_sec: 12000000,
					avg_attempts_sec: 11000000,
					current_job: 'Project Alpha / Campaign 1 / Attack 1'
				},
				{
					id: 2,
					host_name: 'dev-agent-2',
					operating_system: 'windows',
					state: 'offline',
					temperature: null,
					utilization: 0,
					current_attempts_sec: 0,
					avg_attempts_sec: 0,
					current_job: 'Idle'
				}
			];
			agents.set(mock);
			total.set(2);
			error.set('Failed to fetch agents. Showing mock data.');
		} finally {
			loading.set(false);
		}
	}

	onMount(() => {
		fetchAgents();
	});

	function handlePageChange(newPage: number) {
		page.set(newPage);
		fetchAgents(newPage, $search);
	}

	function handleSearch(e: Event) {
		const value = (e.target as HTMLInputElement).value;
		search.set(value);
		fetchAgents(1, value);
	}

	function openAgentModal(agent: AgentListItem) {
		selectedAgent.set(agent);
		agentDetailsFormStore.set(
			superForm(
				{
					gpuEnabled: true,
					cpuEnabled: true,
					updateInterval: 30
				},
				{
					id: `agent-${agent.id}`,
					SPA: true,
					validators: zodClient(agentFormSchema),
					dataType: 'json'
				}
			).form
		);
		showModal.set(true);
	}

	function closeAgentModal() {
		showModal.set(false);
		selectedAgent.set(null);
	}

	function statusBadge(state: string): {
		label: string;
		color: 'default' | 'secondary' | 'outline' | 'destructive';
	} {
		switch (state) {
			case 'active':
				return { label: 'Online', color: 'default' };
			case 'offline':
				return { label: 'Offline', color: 'secondary' };
			case 'stopped':
				return { label: 'Stopped', color: 'outline' };
			case 'error':
				return { label: 'Error', color: 'destructive' };
			default:
				return { label: state, color: 'secondary' };
		}
	}
</script>

<div class="flex flex-col gap-4">
	<div class="flex items-center justify-between gap-2">
		<h2 class="text-xl font-semibold">Agents</h2>
		<input
			type="text"
			class="input input-bordered w-64"
			placeholder="Search agents..."
			on:input={handleSearch}
			value={$search}
		/>
	</div>
	{#if $loading}
		<div class="text-muted-foreground py-8 text-center">Loading agents...</div>
	{:else}
		{#if $error}
			<div class="alert alert-warning">{$error}</div>
		{/if}
		<Table>
			<TableHeader>
				<TableRow>
					<TableHead>Agent Name + OS</TableHead>
					<TableHead>Status</TableHead>
					<TableHead>Temperature (°C)</TableHead>
					<TableHead>Utilization</TableHead>
					<TableHead>Current Attempts/sec</TableHead>
					<TableHead>Average Attempts/sec</TableHead>
					<TableHead>Current Job</TableHead>
					{#if isAdmin}
						<TableHead></TableHead>
					{/if}
				</TableRow>
			</TableHeader>
			<TableBody>
				{#each $agents as agent (agent.id)}
					<TableRow>
						<TableCell>
							<div class="flex flex-col">
								<span class="font-medium">{agent.host_name}</span>
								<span class="text-muted-foreground text-xs"
									>{agent.operating_system}</span
								>
							</div>
						</TableCell>
						<TableCell>
							<Badge variant={statusBadge(agent.state).color}
								>{statusBadge(agent.state).label}</Badge
							>
						</TableCell>
						<TableCell>{agent.temperature ?? '—'}</TableCell>
						<TableCell>
							{#if agent.utilization != null}
								<span>{Math.round(agent.utilization * 100)}%</span>
							{:else}
								—
							{/if}
						</TableCell>
						<TableCell>
							{agent.current_attempts_sec
								? agent.current_attempts_sec.toLocaleString()
								: '—'}
						</TableCell>
						<TableCell>
							{agent.avg_attempts_sec ? agent.avg_attempts_sec.toLocaleString() : '—'}
						</TableCell>
						<TableCell>{agent.current_job ?? '—'}</TableCell>
						{#if isAdmin}
							<TableCell>
								<Button
									variant="ghost"
									size="icon"
									aria-label="Agent Details"
									onclick={() => openAgentModal(agent)}
								>
									<CogIcon class="size-4" />
								</Button>
							</TableCell>
						{/if}
					</TableRow>
				{/each}
			</TableBody>
		</Table>
		<div class="mt-4 flex justify-center">
			<Pagination.Root
				count={$total}
				perPage={pageSize}
				page={$page}
				onPageChange={handlePageChange}
			>
				{#snippet children({ pages, currentPage })}
					<Pagination.Content>
						<Pagination.Item>
							<Pagination.PrevButton />
						</Pagination.Item>
						{#each pages as page (page.key)}
							{#if page.type === 'ellipsis'}
								<Pagination.Item>
									<Pagination.Ellipsis />
								</Pagination.Item>
							{:else}
								<Pagination.Item>
									<Pagination.Link {page} isActive={currentPage === page.value}>
										{page.value}
									</Pagination.Link>
								</Pagination.Item>
							{/if}
						{/each}
						<Pagination.Item>
							<Pagination.NextButton />
						</Pagination.Item>
					</Pagination.Content>
				{/snippet}
			</Pagination.Root>
		</div>
	{/if}
</div>

<Dialog bind:open={$showModal} onOpenChange={() => closeAgentModal()}>
	<AgentDetailsModal
		agent={$selectedAgent}
		form={$agentDetailsFormStore}
		on:close={closeAgentModal}
	/>
</Dialog>
