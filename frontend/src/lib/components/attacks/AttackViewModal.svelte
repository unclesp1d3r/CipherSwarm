<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { Dialog, DialogContent, DialogHeader, DialogTitle } from '$lib/components/ui/dialog';
	import { Button } from '$lib/components/ui/button';
	import { Input } from '$lib/components/ui/input';
	import { Label } from '$lib/components/ui/label';
	import { Textarea } from '$lib/components/ui/textarea';
	import { Badge } from '$lib/components/ui/badge';
	import { Alert, AlertDescription } from '$lib/components/ui/alert';
	import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/ui/card';
	import CircleIcon from '@lucide/svelte/icons/circle';
	import CircleDotIcon from '@lucide/svelte/icons/circle-dot';
	import PerformanceSummary from './PerformanceSummary.svelte';
	import axios from 'axios';

	export let open = false;
	export let attack: Attack | null = null;

	interface Attack {
		id?: number;
		name?: string;
		attack_mode?: string;
		mask?: string;
		language?: string;
		min_length?: number;
		max_length?: number;
		increment_minimum?: number;
		increment_maximum?: number;
		keyspace?: number;
		complexity_score?: number;
		created_at?: string;
		updated_at?: string;
		type?: string;
		comment?: string;
		description?: string;
		state?: string;
		[key: string]: unknown;
	}

	interface Performance {
		total_hashes?: number;
		estimated_time?: string;
		speed?: number;
		progress?: number;
	}

	let loading = true;
	let error = '';
	let performance: Performance | null = null;

	const dispatch = createEventDispatcher();

	// Reactive statements
	$: if (open && attack) {
		loadPerformanceData();
	}

	async function loadPerformanceData() {
		if (!attack?.id) return;

		loading = true;
		error = '';

		try {
			const response = await axios.get(`/api/v1/web/attacks/${attack.id}/performance`);
			performance = response.data;
		} catch (e: unknown) {
			console.error('Failed to load performance data:', e);
			const error_obj = e as { response?: { status?: number } };
			if (error_obj.response?.status === 404) {
				performance = null; // No performance data available
			} else {
				error = 'Failed to load performance data.';
			}
		} finally {
			loading = false;
		}
	}

	function getAttackTypeLabel(type: string): string {
		switch (type) {
			case 'dictionary':
				return 'Dictionary';
			case 'mask':
				return 'Mask';
			case 'brute_force':
				return 'Brute Force';
			case 'hybrid_dictionary':
				return 'Hybrid Dictionary';
			case 'hybrid_mask':
				return 'Hybrid Mask';
			default:
				return type.replace('_', ' ').toUpperCase();
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

	function renderComplexityDots(score?: number) {
		const complexityScore = score || 0;
		const dots = [];
		for (let i = 1; i <= 5; i++) {
			dots.push(i <= complexityScore);
		}
		return dots;
	}

	function formatKeyspace(keyspace?: number): string {
		if (!keyspace) return 'N/A';

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

	function formatSpeed(speed?: number): string {
		if (!speed) return 'N/A';

		if (speed > 1e9) {
			return `${(speed / 1e9).toFixed(1)}GH/s`;
		} else if (speed > 1e6) {
			return `${(speed / 1e6).toFixed(1)}MH/s`;
		} else if (speed > 1e3) {
			return `${(speed / 1e3).toFixed(1)}KH/s`;
		}
		return `${speed.toFixed(0)}H/s`;
	}

	function handleClose() {
		open = false;
		dispatch('close');
	}

	// Reset data when modal closes
	$: if (!open) {
		error = '';
		performance = null;
		loading = true;
	}
</script>

<Dialog bind:open>
	<DialogContent class="max-h-[90vh] max-w-2xl overflow-y-auto">
		<DialogHeader>
			<DialogTitle>Attack Details</DialogTitle>
		</DialogHeader>

		{#if error}
			<Alert variant="destructive">
				<AlertDescription>{error}</AlertDescription>
			</Alert>
		{:else if attack}
			<div class="space-y-6">
				<!-- Basic Information -->
				<Card>
					<CardHeader>
						<CardTitle>Basic Information</CardTitle>
					</CardHeader>
					<CardContent class="space-y-4">
						<div>
							<Label>Name</Label>
							<Input value={attack.name} readonly class="bg-muted" />
						</div>

						<div>
							<Label>Attack Mode</Label>
							<div class="mt-1">
								<Badge
									data-testid="attack-type-badge"
									class="bg-secondary text-secondary-foreground"
								>
									{getAttackTypeLabel(attack.attack_mode || attack.type || '')}
								</Badge>
							</div>
						</div>

						<div>
							<Label>State</Label>
							<div class="mt-1">
								{#if attack.state}
									{@const stateBadge = getStateBadge(attack.state)}
									<Badge class={stateBadge.color}>{stateBadge.label}</Badge>
								{:else}
									—
								{/if}
							</div>
						</div>

						{#if attack.description}
							<div>
								<Label>Description</Label>
								<Textarea
									value={attack.description || ''}
									readonly
									class="bg-muted"
								/>
							</div>
						{/if}

						{#if attack.comment}
							<div>
								<Label>Comment</Label>
								<Textarea value={attack.comment || ''} readonly class="bg-muted" />
							</div>
						{/if}
					</CardContent>
				</Card>

				<!-- Attack Settings -->
				<Card>
					<CardHeader>
						<CardTitle>Attack Settings</CardTitle>
					</CardHeader>
					<CardContent class="space-y-4">
						{#if attack.attack_mode === 'dictionary' || attack.type === 'dictionary'}
							<div class="grid grid-cols-2 gap-4">
								<div>
									<Label>Min Length</Label>
									<Input
										value={attack.min_length || attack.length_min || 'N/A'}
										readonly
										class="bg-muted"
									/>
								</div>
								<div>
									<Label>Max Length</Label>
									<Input
										value={attack.max_length || attack.length_max || 'N/A'}
										readonly
										class="bg-muted"
									/>
								</div>
							</div>

							{#if attack.word_list_name}
								<div>
									<Label>Wordlist</Label>
									<Input
										value={attack.word_list_name}
										readonly
										class="bg-muted"
									/>
								</div>
							{/if}

							{#if attack.rule_list_name}
								<div>
									<Label>Rule List</Label>
									<Input
										value={attack.rule_list_name}
										readonly
										class="bg-muted"
									/>
								</div>
							{/if}
						{/if}

						{#if attack.attack_mode === 'mask' || attack.type === 'mask'}
							{#if attack.mask}
								<div>
									<Label>Mask</Label>
									<Input value={attack.mask} readonly class="bg-muted" />
								</div>
							{/if}

							{#if attack.language}
								<div>
									<Label>Language</Label>
									<Input value={attack.language} readonly class="bg-muted" />
								</div>
							{/if}
						{/if}

						{#if attack.attack_mode === 'brute_force' || attack.type === 'brute_force'}
							<div class="grid grid-cols-2 gap-4">
								<div>
									<Label>Min Length</Label>
									<Input
										value={attack.increment_minimum || 'N/A'}
										readonly
										class="bg-muted"
									/>
								</div>
								<div>
									<Label>Max Length</Label>
									<Input
										value={attack.increment_maximum || 'N/A'}
										readonly
										class="bg-muted"
									/>
								</div>
							</div>

							{#if attack.custom_charset_1}
								<div>
									<Label>Character Set</Label>
									<Input
										value={attack.custom_charset_1}
										readonly
										class="bg-muted"
									/>
								</div>
							{/if}
						{/if}

						{#if attack.hash_type_id}
							<div>
								<Label>Hash Type ID</Label>
								<Input value={attack.hash_type_id} readonly class="bg-muted" />
							</div>
						{/if}
					</CardContent>
				</Card>

				<!-- Complexity & Keyspace -->
				<Card>
					<CardHeader>
						<CardTitle>Complexity & Keyspace</CardTitle>
					</CardHeader>
					<CardContent class="space-y-4">
						<div>
							<Label>Keyspace</Label>
							<Input
								value={formatKeyspace(attack.keyspace || performance?.total_hashes)}
								readonly
								class="bg-muted"
							/>
						</div>

						{#if attack.complexity_score !== undefined && attack.complexity_score !== null}
							<div>
								<Label>Complexity Score</Label>
								<div class="mt-1 flex items-center gap-2">
									<Input
										value={attack.complexity_score}
										readonly
										class="bg-muted w-20"
									/>
									<div class="flex gap-1">
										{#each renderComplexityDots(attack.complexity_score) as filled, i (i)}
											{#if filled}
												<CircleDotIcon
													class="h-4 w-4 fill-current text-green-500"
												/>
											{:else}
												<CircleIcon class="h-4 w-4 text-gray-400" />
											{/if}
										{/each}
									</div>
								</div>
							</div>
						{/if}
					</CardContent>
				</Card>

				<!-- Performance Data -->
				{#if loading}
					<Card>
						<CardHeader>
							<CardTitle data-testid="section-performance-data"
								>Performance Data</CardTitle
							>
						</CardHeader>
						<CardContent>
							<p class="text-muted-foreground">Loading performance data...</p>
						</CardContent>
					</Card>
				{:else if performance}
					<div data-testid="section-performance-data">
						<PerformanceSummary
							attackName={attack.name || 'Unknown Attack'}
							totalHashes={performance.total_hashes}
							hashesDone={0}
							hashesPerSec={performance.speed}
							progress={performance.progress}
							eta={performance.estimated_time
								? parseInt(performance.estimated_time)
								: undefined}
							agentCount={1}
						/>
					</div>
				{/if}

				<!-- Timestamps -->
				<Card>
					<CardHeader>
						<CardTitle>Timestamps</CardTitle>
					</CardHeader>
					<CardContent class="space-y-4">
						{#if attack.created_at}
							<div>
								<Label>Created</Label>
								<Input
									value={new Date(attack.created_at).toLocaleString()}
									readonly
									class="bg-muted"
								/>
							</div>
						{/if}

						{#if attack.updated_at}
							<div>
								<Label>Last Updated</Label>
								<Input
									value={new Date(attack.updated_at).toLocaleString()}
									readonly
									class="bg-muted"
								/>
							</div>
						{/if}
					</CardContent>
				</Card>
			</div>
		{/if}

		<!-- Footer -->
		<div class="flex justify-end">
			<Button onclick={handleClose} data-testid="footer-close">Close</Button>
		</div>
	</DialogContent>
</Dialog>
