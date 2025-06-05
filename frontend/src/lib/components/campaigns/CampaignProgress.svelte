<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import axios from 'axios';
	import { Card, CardHeader, CardTitle, CardContent } from '$lib/components/ui/card';
	import { Badge } from '$lib/components/ui/badge';
	import { Progress } from '$lib/components/ui/progress';
	import { Alert, AlertDescription } from '$lib/components/ui/alert';

	export let campaignId: number;
	export let refreshInterval: number = 5000; // 5 seconds default

	interface CampaignProgress {
		total_tasks: number;
		active_agents: number;
		completed_tasks: number;
		pending_tasks: number;
		active_tasks: number;
		failed_tasks: number;
		percentage_complete: number;
		overall_status: string | null;
		active_attack_id: number | null;
	}

	let progress: CampaignProgress | null = null;
	let loading = true;
	let error = '';
	let intervalId: NodeJS.Timeout | null = null;

	async function fetchProgress() {
		try {
			const response = await axios.get(`/api/v1/web/campaigns/${campaignId}/progress`);
			progress = response.data;
			error = '';
		} catch (e) {
			error = 'Failed to load campaign progress.';
			progress = null;
		} finally {
			loading = false;
		}
	}

	function startPolling() {
		if (intervalId) {
			clearInterval(intervalId);
		}
		intervalId = setInterval(fetchProgress, refreshInterval);
	}

	function stopPolling() {
		if (intervalId) {
			clearInterval(intervalId);
			intervalId = null;
		}
	}

	onMount(() => {
		fetchProgress();
		startPolling();
	});

	onDestroy(() => {
		stopPolling();
	});

	function getStatusBadge(status: string | null) {
		switch (status) {
			case 'running':
				return { color: 'bg-green-600', label: 'Running' };
			case 'completed':
				return { color: 'bg-blue-600', label: 'Completed' };
			case 'failed':
				return { color: 'bg-red-600', label: 'Failed' };
			case 'pending':
				return { color: 'bg-yellow-500', label: 'Pending' };
			default:
				return { color: 'bg-gray-400', label: status || 'Unknown' };
		}
	}
</script>

<Card data-testid="campaign-progress-card">
	<CardHeader>
		<CardTitle>Campaign Progress</CardTitle>
	</CardHeader>
	<CardContent>
		{#if loading}
			<div class="py-4 text-center text-gray-500" data-testid="progress-loading">
				Loading progress...
			</div>
		{:else if error}
			<Alert variant="destructive">
				<AlertDescription data-testid="progress-error">{error}</AlertDescription>
			</Alert>
		{:else if progress}
			<div class="space-y-4">
				<!-- Progress Bar -->
				<div class="space-y-2">
					<div class="flex items-center justify-between">
						<span class="text-sm font-medium">Overall Progress</span>
						<span class="text-sm text-gray-600" data-testid="progress-percentage">
							{progress.percentage_complete.toFixed(1)}%
						</span>
					</div>
					<Progress
						value={progress.percentage_complete}
						class="h-2"
						data-testid="campaign-progress-bar"
					/>
				</div>

				<!-- Status and Agents -->
				<div class="flex items-center justify-between">
					<div class="flex items-center gap-2">
						<span class="text-sm font-medium">Status:</span>
						<Badge
							class={getStatusBadge(progress.overall_status).color}
							data-testid="progress-status"
						>
							{getStatusBadge(progress.overall_status).label}
						</Badge>
					</div>
					<div class="text-sm text-gray-600" data-testid="active-agents">
						<span class="font-medium">Active Agents:</span>
						{progress.active_agents}
					</div>
				</div>

				<!-- Task Breakdown -->
				<div class="grid grid-cols-2 gap-4 text-sm">
					<div class="space-y-1">
						<div class="flex justify-between" data-testid="total-tasks">
							<span class="text-gray-600">Total Tasks:</span>
							<span class="font-medium">{progress.total_tasks}</span>
						</div>
						<div class="flex justify-between" data-testid="completed-tasks">
							<span class="text-gray-600">Completed:</span>
							<span class="font-medium text-green-600"
								>{progress.completed_tasks}</span
							>
						</div>
						<div class="flex justify-between" data-testid="active-tasks">
							<span class="text-gray-600">Active:</span>
							<span class="font-medium text-blue-600">{progress.active_tasks}</span>
						</div>
					</div>
					<div class="space-y-1">
						<div class="flex justify-between" data-testid="pending-tasks">
							<span class="text-gray-600">Pending:</span>
							<span class="font-medium text-yellow-600">{progress.pending_tasks}</span
							>
						</div>
						<div class="flex justify-between" data-testid="failed-tasks">
							<span class="text-gray-600">Failed:</span>
							<span class="font-medium text-red-600">{progress.failed_tasks}</span>
						</div>
						{#if progress.active_attack_id}
							<div class="flex justify-between" data-testid="active-attack">
								<span class="text-gray-600">Active Attack:</span>
								<span class="font-medium">#{progress.active_attack_id}</span>
							</div>
						{/if}
					</div>
				</div>
			</div>
		{:else}
			<div class="py-4 text-center text-gray-500" data-testid="no-progress-data">
				No progress data available.
			</div>
		{/if}
	</CardContent>
</Card>
