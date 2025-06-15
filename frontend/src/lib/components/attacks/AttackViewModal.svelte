<script lang="ts">
	import { Dialog, DialogContent, DialogHeader, DialogTitle } from '$lib/components/ui/dialog';
	import { Button } from '$lib/components/ui/button';
	import { Input } from '$lib/components/ui/input';
	import { Label } from '$lib/components/ui/label';
	import { Textarea } from '$lib/components/ui/textarea';
	import { Badge } from '$lib/components/ui/badge';
	import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/ui/card';
	import { Separator } from '$lib/components/ui/separator';
	import { Clock, Hash, Zap, Users } from 'lucide-svelte';
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import PerformanceSummary from './PerformanceSummary.svelte';
	import {
		attacksActions,
		type Attack,
		type AttackPerformance
	} from '$lib/stores/attacks.svelte';

	// Props using SvelteKit 5 runes
	let { open = $bindable(false), attack = null }: { open?: boolean; attack?: Attack | null } =
		$props();

	// Local state for full attack details
	let fullAttack = $state<Attack | null>(null);
	let loadingAttack = $state(false);
	let previousAttackId = $state<string | null>(null);

	// Convert number ID to string for store functions
	const attackId = $derived(attack?.id ? String(attack.id) : null);

	// Local state for attack performance data
	let performance = $state<AttackPerformance | null>(null);
	let performanceLoading = $state(false);
	let performanceError = $state<string | null>(null);

	// Use full attack details if available, otherwise fall back to basic attack prop
	const displayAttack = $derived(fullAttack || attack);

	// Handle modal opening and attack changes using $effect
	$effect(() => {
		if (open && attackId && attackId !== previousAttackId) {
			handleAttackChange(attackId);
		}
	});

	// Handle modal closing using $effect
	$effect(() => {
		if (!open && (fullAttack || loadingAttack)) {
			resetAttackDetails();
		}
	});

	function handleAttackChange(id: string) {
		previousAttackId = id;
		fullAttack = null;
		loadFullAttackDetails(id);

		// Load performance data if not already loading
		if (!performanceLoading && !performance) {
			loadAttackPerformance(id);
		}
	}

	async function loadAttackPerformance(attackId: string) {
		if (!browser) return;

		performanceLoading = true;
		performanceError = null;

		try {
			const response = await fetch(`/api/v1/web/attacks/${attackId}/performance`);

			if (response.status === 404) {
				// No performance data available yet - this is normal
				performanceError = null;
				return;
			}

			if (!response.ok) {
				throw new Error(`HTTP ${response.status}`);
			}

			const data = await response.json();
			performance = {
				hashes_done: data.hashes_done || 0,
				hashes_per_sec: data.hashes_per_sec || 0,
				eta: data.eta || 'Unknown',
				agent_count: data.agent_count || 0,
				total_hashes: data.total_hashes || 0,
				progress: data.progress || 0
			};
		} catch (error) {
			console.error(`Failed to load attack performance for ${attackId}:`, error);
			performanceError = 'Failed to load performance data';
		} finally {
			performanceLoading = false;
		}
	}

	async function loadFullAttackDetails(attackId: string) {
		// Skip API calls only in unit test environment (VITEST), not in E2E tests
		if (typeof window === 'undefined' || process.env.VITEST) {
			return;
		}

		try {
			loadingAttack = true;
			const baseUrl = browser ? '' : 'http://localhost:8000';
			const response = await fetch(`${baseUrl}/api/v1/web/attacks/${attackId}`);

			if (response.ok) {
				const attackData = await response.json();
				fullAttack = attackData;
			} else {
				console.warn(`Failed to load attack details: ${response.status}`);
			}
		} catch (error) {
			console.error('Failed to load attack details:', error);
		} finally {
			loadingAttack = false;
		}
	}

	function resetAttackDetails() {
		fullAttack = null;
		loadingAttack = false;
		previousAttackId = null;
	}

	function formatKeyspace(keyspace: number | undefined): string {
		if (!keyspace) return 'Unknown';
		if (keyspace > 1e12) {
			return `${(keyspace / 1e12).toFixed(1)}T`;
		} else if (keyspace > 1e9) {
			return `${(keyspace / 1e9).toFixed(1)}B`;
		} else if (keyspace > 1e6) {
			return `${(keyspace / 1e6).toFixed(1)}M`;
		} else if (keyspace > 1e3) {
			return `${(keyspace / 1e3).toFixed(1)}K`;
		}
		return keyspace.toLocaleString();
	}

	function formatHashRate(rate: number): string {
		if (rate > 1e9) {
			return `${(rate / 1e9).toFixed(1)} GH/s`;
		} else if (rate > 1e6) {
			return `${(rate / 1e6).toFixed(1)} MH/s`;
		} else if (rate > 1e3) {
			return `${(rate / 1e3).toFixed(1)} KH/s`;
		}
		return `${rate} H/s`;
	}

	function formatEta(eta: string | number): string {
		if (typeof eta === 'string') return eta;
		if (typeof eta === 'number') {
			// Convert seconds to human readable format
			const hours = Math.floor(eta / 3600);
			const minutes = Math.floor((eta % 3600) / 60);
			const seconds = eta % 60;
			return `${hours}h ${minutes}m ${seconds}s`;
		}
		return 'Unknown';
	}

	function getStateColor(state: string): string {
		switch (state) {
			case 'running':
				return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200';
			case 'completed':
				return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200';
			case 'paused':
				return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200';
			case 'error':
				return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200';
			case 'pending':
				return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200';
			default:
				return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200';
		}
	}
</script>

<Dialog bind:open>
	<DialogContent class="max-h-[90vh] max-w-4xl overflow-y-auto">
		<DialogHeader>
			<DialogTitle class="flex items-center gap-2">
				<Hash class="h-5 w-5" />
				Attack Details
			</DialogTitle>
		</DialogHeader>

		{#if displayAttack}
			<div class="space-y-6">
				<!-- Attack Title -->
				<div class="text-center">
					<h2 class="text-xl font-semibold">
						Attack: {displayAttack.name || 'Unknown Attack'}
					</h2>
					{#if displayAttack.comment}
						<p class="text-muted-foreground mt-2">{displayAttack.comment}</p>
					{/if}
				</div>

				<!-- Basic Information -->
				<Card>
					<CardHeader>
						<CardTitle class="text-lg">Basic Information</CardTitle>
					</CardHeader>
					<CardContent class="space-y-4">
						<div class="grid grid-cols-1 gap-4 md:grid-cols-2">
							<div>
								<Label>Attack Name</Label>
								<Input value={displayAttack.name || ''} readonly class="bg-muted" />
							</div>
							<div>
								<Label>Attack Mode</Label>
								<Input
									value={displayAttack.attack_mode || displayAttack.type || ''}
									readonly
									class="bg-muted"
								/>
							</div>
							<div>
								<Label>State</Label>
								<Badge
									data-testid="attack-type-badge"
									class={getStateColor(displayAttack.state || 'unknown')}
								>
									{displayAttack.state || 'Unknown'}
								</Badge>
							</div>
							<div>
								<Label>Created</Label>
								<Input
									value={displayAttack.created_at
										? new Date(displayAttack.created_at).toLocaleString()
										: ''}
									readonly
									class="bg-muted"
								/>
							</div>
						</div>
					</CardContent>
				</Card>

				<!-- Complexity & Keyspace -->
				<Card>
					<CardHeader>
						<CardTitle class="text-lg">Complexity & Keyspace</CardTitle>
					</CardHeader>
					<CardContent class="space-y-4">
						<div class="grid grid-cols-1 gap-4 md:grid-cols-2">
							{#if displayAttack.word_list_name}
								<div>
									<Label>Word List</Label>
									<Input
										value={displayAttack.word_list_name}
										readonly
										class="bg-muted"
									/>
								</div>
							{/if}

							{#if displayAttack.rule_list_name}
								<div>
									<Label>Rule List</Label>
									<Input
										value={displayAttack.rule_list_name}
										readonly
										class="bg-muted"
									/>
								</div>
							{/if}
						</div>

						{#if displayAttack.attack_mode === 'mask' || displayAttack.type === 'mask'}
							{#if displayAttack.mask}
								<div>
									<Label>Mask</Label>
									<Input value={displayAttack.mask} readonly class="bg-muted" />
								</div>
							{/if}
						{/if}

						{#if displayAttack.attack_mode === 'dictionary' || displayAttack.type === 'dictionary'}
							<div class="grid grid-cols-1 gap-4 md:grid-cols-2">
								{#if displayAttack.min_length}
									<div>
										<Label>Min Length</Label>
										<Input
											value={displayAttack.min_length}
											readonly
											class="bg-muted"
										/>
									</div>
								{/if}
								{#if displayAttack.max_length}
									<div>
										<Label>Max Length</Label>
										<Input
											value={displayAttack.max_length}
											readonly
											class="bg-muted"
										/>
									</div>
								{/if}
							</div>
						{:else if displayAttack.min_length || displayAttack.max_length}
							<div class="grid grid-cols-1 gap-4 md:grid-cols-2">
								{#if displayAttack.min_length}
									<div>
										<Label>Min Length</Label>
										<Input
											value={displayAttack.min_length}
											readonly
											class="bg-muted"
										/>
									</div>
								{/if}
								{#if displayAttack.max_length}
									<div>
										<Label>Max Length</Label>
										<Input
											value={displayAttack.max_length}
											readonly
											class="bg-muted"
										/>
									</div>
								{/if}
							</div>
						{/if}

						{#if displayAttack.custom_charset_1}
							<div>
								<Label>Custom Charset 1</Label>
								<Input
									value={displayAttack.custom_charset_1}
									readonly
									class="bg-muted"
								/>
							</div>
						{/if}

						{#if displayAttack.hash_type_id}
							<div>
								<Label>Hash Type ID</Label>
								<Input
									value={displayAttack.hash_type_id}
									readonly
									class="bg-muted"
								/>
							</div>
						{/if}

						<Separator />

						<div class="grid grid-cols-1 gap-4 md:grid-cols-2">
							<div>
								<Label>Keyspace</Label>
								<Input
									value={formatKeyspace(
										displayAttack.keyspace || performance?.total_hashes
									)}
									readonly
									class="bg-muted"
								/>
							</div>
						</div>
					</CardContent>
				</Card>

				<!-- Performance Metrics -->
				{#if performance || performanceLoading}
					<Card data-testid="section-performance-data">
						<CardHeader>
							<CardTitle class="flex items-center gap-2 text-lg">
								<Zap class="h-5 w-5" />
								Performance Metrics
							</CardTitle>
						</CardHeader>
						<CardContent>
							{#if performanceLoading}
								<div class="flex items-center justify-center py-8">
									<div
										class="border-primary h-8 w-8 animate-spin rounded-full border-b-2"
									></div>
									<span class="ml-2">Loading performance data...</span>
								</div>
							{:else if performanceError}
								<div class="text-muted-foreground py-8 text-center">
									<p>No performance data available</p>
								</div>
							{:else if performance}
								<div class="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
									<div class="text-center">
										<div class="text-primary text-2xl font-bold">
											{formatHashRate(performance.hashes_per_sec)}
										</div>
										<div class="text-muted-foreground text-sm">Hash Rate</div>
									</div>
									<div class="text-center">
										<div class="text-primary text-2xl font-bold">
											{performance.hashes_done.toLocaleString()}
										</div>
										<div class="text-muted-foreground text-sm">Hashes Done</div>
									</div>
									<div class="text-center">
										<div class="text-primary text-2xl font-bold">
											{formatEta(performance.eta)}
										</div>
										<div class="text-muted-foreground text-sm">ETA</div>
									</div>
									<div class="text-center">
										<div class="text-primary text-2xl font-bold">
											{performance.agent_count}
										</div>
										<div class="text-muted-foreground text-sm">
											Active Agents
										</div>
									</div>
								</div>
							{/if}
						</CardContent>
					</Card>
				{/if}

				<!-- Progress Summary -->
				{#if performance && performance.total_hashes}
					<Card>
						<CardHeader>
							<CardTitle class="flex items-center gap-2 text-lg">
								<Clock class="h-5 w-5" />
								Progress Summary
							</CardTitle>
						</CardHeader>
						<CardContent>
							<PerformanceSummary
								attackName={displayAttack.name || 'Unknown Attack'}
								totalHashes={performance.total_hashes}
								hashesDone={performance.hashes_done}
								hashesPerSec={performance.hashes_per_sec}
								progress={performance.progress || 0}
								eta={typeof performance.eta === 'number' ? performance.eta : 0}
								agentCount={performance.agent_count}
							/>
						</CardContent>
					</Card>
				{/if}

				<!-- Timestamps -->
				<Card>
					<CardHeader>
						<CardTitle class="text-lg">Timestamps</CardTitle>
					</CardHeader>
					<CardContent class="space-y-4">
						<div class="grid grid-cols-1 gap-4 md:grid-cols-2">
							<div>
								<Label>Created At</Label>
								<Input
									value={displayAttack.created_at
										? new Date(displayAttack.created_at).toLocaleString()
										: 'N/A'}
									readonly
									class="bg-muted"
								/>
							</div>
							<div>
								<Label>Updated At</Label>
								<Input
									value={displayAttack.updated_at
										? new Date(displayAttack.updated_at).toLocaleString()
										: 'N/A'}
									readonly
									class="bg-muted"
								/>
							</div>
						</div>
					</CardContent>
				</Card>
			</div>
		{:else}
			<div class="text-muted-foreground py-8 text-center">
				<p>No attack selected</p>
			</div>
		{/if}

		<div class="flex justify-end pt-4">
			<Button variant="outline" data-testid="footer-close" onclick={() => (open = false)}
				>Close</Button
			>
		</div>
	</DialogContent>
</Dialog>
