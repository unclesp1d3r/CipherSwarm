<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
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
	import { Progress } from '$lib/components/ui/progress';
	import {
		DropdownMenu,
		DropdownMenuTrigger,
		DropdownMenuContent,
		DropdownMenuItem
	} from '$lib/components/ui/dropdown-menu';
	import { Alert, AlertDescription } from '$lib/components/ui/alert';
	import { goto } from '$app/navigation';
	import CampaignProgress from '$lib/components/campaigns/CampaignProgress.svelte';
	import CampaignMetrics from '$lib/components/campaigns/CampaignMetrics.svelte';
	import AttackTableBody from '$lib/components/attacks/AttackTableBody.svelte';

	interface Attack {
		id: number;
		type: string;
		language: string;
		length_min: number;
		length_max: number;
		settings_summary: string;
		keyspace: number;
		complexity_score: number;
		position: number;
		comment?: string;
		state: string;
	}

	interface Campaign {
		id: number;
		name: string;
		description?: string;
		state: string;
		progress: number;
		attacks: Attack[];
		created_at: string;
		updated_at: string;
	}

	let campaign: Campaign | null = null;
	let loading = true;
	let error = '';
	let campaignId = $page.params.id;

	async function fetchCampaign() {
		loading = true;
		error = '';
		try {
			const response = await axios.get(`/api/v1/web/campaigns/${campaignId}`);
			campaign = response.data;
		} catch (e) {
			error = 'Failed to load campaign details.';
			campaign = null;
		} finally {
			loading = false;
		}
	}

	onMount(fetchCampaign);

	function getStateBadge(state: string) {
		switch (state) {
			case 'running':
				return { color: 'bg-green-600', label: 'Running' };
			case 'completed':
				return { color: 'bg-blue-600', label: 'Completed' };
			case 'error':
				return { color: 'bg-red-600', label: 'Error' };
			case 'paused':
				return { color: 'bg-yellow-500', label: 'Paused' };
			case 'draft':
				return { color: 'bg-gray-400', label: 'Draft' };
			default:
				return { color: 'bg-gray-200', label: state };
		}
	}

	function getAttackTypeBadge(type: string) {
		switch (type) {
			case 'dictionary':
				return { color: 'bg-blue-500', label: 'Dictionary' };
			case 'mask':
				return { color: 'bg-purple-500', label: 'Mask' };
			case 'brute_force':
				return { color: 'bg-orange-500', label: 'Brute Force' };
			case 'hybrid_dictionary':
				return { color: 'bg-teal-500', label: 'Hybrid Dictionary' };
			case 'hybrid_mask':
				return { color: 'bg-pink-500', label: 'Hybrid Mask' };
			default:
				return { color: 'bg-gray-400', label: type };
		}
	}

	function formatLength(minLength: number, maxLength: number): string {
		if (minLength === maxLength) {
			return String(minLength);
		}
		return `${minLength} → ${maxLength}`;
	}

	function formatKeyspace(keyspace: number): string {
		return keyspace.toLocaleString();
	}

	function transformAttacksForTable(attacks: Attack[]) {
		return attacks
			.sort((a, b) => a.position - b.position)
			.map((attack) => ({
				id: attack.id.toString(),
				name: getAttackTypeBadge(attack.type).label,
				type_label: attack.language || '—',
				length_range: formatLength(attack.length_min, attack.length_max),
				settings_summary: attack.settings_summary,
				keyspace: attack.keyspace,
				complexity_score: attack.complexity_score,
				comment: attack.comment || '',
				type: attack.type,
				type_badge: getAttackTypeBadge(attack.type)
			}));
	}

	async function handleMoveAttackCallback(
		attackId: string,
		direction: 'up' | 'down' | 'top' | 'bottom'
	) {
		try {
			await axios.post(`/api/v1/web/attacks/${attackId}/move`, { direction });
			await fetchCampaign(); // Refresh data
		} catch (e) {
			error = 'Failed to move attack.';
		}
	}

	function renderComplexityDots(score: number): string {
		return '●'.repeat(score) + '○'.repeat(5 - score);
	}

	async function handleEditAttack(attackId: number) {
		// TODO: Implement attack edit modal
		console.log('Edit attack:', attackId);
	}

	async function handleDuplicateAttack(attackId: number) {
		try {
			await axios.post(`/api/v1/web/attacks/${attackId}/duplicate`);
			await fetchCampaign(); // Refresh data
		} catch (e) {
			error = 'Failed to duplicate attack.';
		}
	}

	async function handleMoveAttack(attackId: number, direction: 'up' | 'down') {
		try {
			await axios.post(`/api/v1/web/attacks/${attackId}/move`, { direction });
			await fetchCampaign(); // Refresh data
		} catch (e) {
			error = 'Failed to move attack.';
		}
	}

	async function handleRemoveAttack(attackId: number) {
		if (confirm('Are you sure you want to remove this attack?')) {
			try {
				await axios.delete(`/api/v1/web/attacks/${attackId}`);
				await fetchCampaign(); // Refresh data
			} catch (e) {
				error = 'Failed to remove attack.';
			}
		}
	}

	async function handleAddAttack() {
		// TODO: Implement add attack modal
		console.log('Add attack to campaign:', campaignId);
	}

	async function handleRemoveAllAttacks() {
		if (confirm('Remove all attacks from this campaign?')) {
			try {
				await axios.post(`/api/v1/web/campaigns/${campaignId}/clear_attacks`);
				await fetchCampaign(); // Refresh data
			} catch (e) {
				error = 'Failed to remove all attacks.';
			}
		}
	}

	async function handleStartCampaign() {
		try {
			await axios.post(`/api/v1/web/campaigns/${campaignId}/start`);
			await fetchCampaign(); // Refresh data
		} catch (e) {
			error = 'Failed to start campaign.';
		}
	}

	async function handleStopCampaign() {
		try {
			await axios.post(`/api/v1/web/campaigns/${campaignId}/stop`);
			await fetchCampaign(); // Refresh data
		} catch (e) {
			error = 'Failed to stop campaign.';
		}
	}
</script>

<svelte:head>
	<title>{campaign?.name || 'Campaign'} - CipherSwarm</title>
</svelte:head>

<div class="container mx-auto max-w-7xl p-6">
	{#if loading}
		<div class="py-8 text-center" data-testid="loading">Loading campaign details…</div>
	{:else if error}
		<Alert class="mb-4" variant="destructive">
			<AlertDescription data-testid="error">{error}</AlertDescription>
		</Alert>
	{:else if !campaign}
		<Alert class="mb-4" variant="destructive">
			<AlertDescription data-testid="not-found">Campaign not found.</AlertDescription>
		</Alert>
	{:else}
		<!-- Campaign Header -->
		<div class="mb-6">
			<div class="flex items-center justify-between">
				<div>
					<h1
						class="text-2xl font-semibold text-gray-900 dark:text-white"
						data-testid="campaign-name"
					>
						{campaign.name}
					</h1>
					{#if campaign.description}
						<p
							class="mt-1 text-gray-600 dark:text-gray-400"
							data-testid="campaign-description"
						>
							{campaign.description}
						</p>
					{/if}
				</div>
				<div class="flex items-center gap-4">
					<Badge class={getStateBadge(campaign.state).color} data-testid="campaign-state">
						{getStateBadge(campaign.state).label}
					</Badge>
					{#if campaign.state === 'draft' || campaign.state === 'paused'}
						<Button onclick={handleStartCampaign} data-testid="start-campaign">
							Start Campaign
						</Button>
					{:else if campaign.state === 'running'}
						<Button
							onclick={handleStopCampaign}
							variant="outline"
							data-testid="stop-campaign"
						>
							Stop Campaign
						</Button>
					{/if}
				</div>
			</div>

			<!-- Progress Bar -->
			{#if campaign.progress > 0}
				<div class="mt-4">
					<Progress
						value={campaign.progress}
						class="h-2"
						data-testid="campaign-progress"
					/>
					<p class="mt-1 text-sm text-gray-600">Progress: {campaign.progress}%</p>
				</div>
			{/if}
		</div>

		<!-- Progress and Metrics -->
		<div class="mb-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
			<CampaignProgress campaignId={parseInt(campaignId)} />
			<CampaignMetrics campaignId={parseInt(campaignId)} />
		</div>

		<!-- Attacks Table -->
		<Card>
			<CardHeader>
				<div class="flex items-center justify-between">
					<CardTitle>Attacks</CardTitle>
					<div class="flex gap-2">
						<Button onclick={handleAddAttack} data-testid="add-attack">
							+ Add Attack
						</Button>
						{#if campaign.attacks.length > 0}
							<Button
								onclick={handleRemoveAllAttacks}
								variant="outline"
								class="text-red-600"
								data-testid="remove-all-attacks"
							>
								🗑️ All
							</Button>
						{/if}
					</div>
				</div>
			</CardHeader>
			<CardContent>
				{#if campaign.attacks.length === 0}
					<div class="py-8 text-center text-gray-500" data-testid="no-attacks">
						No attacks configured for this campaign.
					</div>
				{:else}
					<Table data-testid="attacks-table">
						<TableHead>
							<TableRow>
								<TableHeader>Name</TableHeader>
								<TableHeader>Type</TableHeader>
								<TableHeader>Length</TableHeader>
								<TableHeader>Settings</TableHeader>
								<TableHeader>Keyspace</TableHeader>
								<TableHeader>Complexity</TableHeader>
								<TableHeader>Comment</TableHeader>
								<TableHeader class="w-16"></TableHeader>
							</TableRow>
						</TableHead>
						<TableBody>
							<AttackTableBody
								attacks={transformAttacksForTable(campaign.attacks)}
								onMoveAttack={handleMoveAttackCallback}
								onEditAttack={(attackId) => handleEditAttack(parseInt(attackId))}
								onDeleteAttack={(attackId) =>
									handleRemoveAttack(parseInt(attackId))}
								onDuplicateAttack={(attackId) =>
									handleDuplicateAttack(parseInt(attackId))}
							/>
						</TableBody>
					</Table>
				{/if}
			</CardContent>
		</Card>

		<!-- Campaign Actions -->
		<div class="mt-6 flex justify-between">
			<Button onclick={() => goto('/campaigns')} variant="outline">
				← Back to Campaigns
			</Button>
			<div class="flex gap-2">
				<!-- TODO: Add more campaign actions like export/import -->
			</div>
		</div>
	{/if}
</div>
