<script lang="ts">
	import { onMount } from 'svelte';
	import Card from '$lib/components/ui/card/card.svelte';
	import CardHeader from '$lib/components/ui/card/card-header.svelte';
	import CardTitle from '$lib/components/ui/card/card-title.svelte';
	import CardContent from '$lib/components/ui/card/card-content.svelte';
	import Progress from '$lib/components/ui/progress/progress.svelte';
	import Badge from '$lib/components/ui/badge/badge.svelte';
	import AccordionRoot from '$lib/components/ui/accordion/accordion-root.svelte';
	import AccordionItem from '$lib/components/ui/accordion/accordion-item.svelte';
	import AccordionTrigger from '$lib/components/ui/accordion/accordion-trigger.svelte';
	import AccordionContent from '$lib/components/ui/accordion/accordion-content.svelte';
	import SheetRoot from '$lib/components/ui/sheet/sheet-content.svelte';
	import SheetHeader from '$lib/components/ui/sheet/sheet-header.svelte';
	import SheetTitle from '$lib/components/ui/sheet/sheet-title.svelte';
	import SheetClose from '$lib/components/ui/sheet/sheet-close.svelte';
	import { toast } from 'svelte-sonner';

	interface ResourceUsage {
		timestamp: string;
		hash_rate: number;
	}

	interface DashboardSummary {
		active_agents: number;
		total_agents: number;
		running_tasks: number;
		total_tasks: number;
		recently_cracked_hashes: number;
		resource_usage: ResourceUsage[];
	}

	interface CampaignItem {
		name: string;
		description: string;
		project_id: number;
		priority: number;
		hash_list_id: number;
		is_unavailable: boolean;
		id: number;
		state: string;
		created_at: string;
		updated_at: string;
		// UI-only fields
		attacks: unknown[];
		progress: number;
		summary: string;
	}

	let showAgentSheet = false;
	let dashboardSummary: DashboardSummary | null = null;
	let campaigns: CampaignItem[] = [];
	let loading = true;
	let error = '';

	function openAgentSheet() {
		showAgentSheet = true;
	}
	function closeAgentSheet() {
		showAgentSheet = false;
	}

	function triggerToast(msg: string) {
		toast(msg);
	}

	onMount(async () => {
		loading = true;
		error = '';
		try {
			const [summaryRes, campaignsRes] = await Promise.all([
				fetch('/api/v1/web/dashboard/summary'),
				fetch('/api/v1/web/campaigns')
			]);
			if (!summaryRes.ok) throw new Error('Failed to fetch dashboard summary');
			if (!campaignsRes.ok) throw new Error('Failed to fetch campaigns');
			dashboardSummary = (await summaryRes.json()) as DashboardSummary;
			const campaignsData = await campaignsRes.json();
			campaigns = (campaignsData.items || []).map(
				(c: Omit<CampaignItem, 'attacks' | 'progress' | 'summary'>) => ({
					...c,
					attacks: [],
					progress: 0,
					summary: '',
					state: c.state || 'draft'
				})
			);
			// Optionally, trigger a toast for demo
			setTimeout(() => triggerToast('5 new hashes cracked!'), 2000);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load dashboard.';
		} finally {
			loading = false;
		}
	});
</script>

<div class="flex flex-col gap-y-6">
	{#if loading}
		<div class="text-muted-foreground py-8 text-center">Loading dashboard...</div>
	{:else if error}
		<div class="py-8 text-center text-red-500">{error}</div>
	{:else}
		<!-- Top Metric Cards -->
		<div class="grid grid-cols-1 gap-4 md:grid-cols-4">
			<button
				type="button"
				class="h-full w-full cursor-pointer text-left"
				on:click={openAgentSheet}
				aria-label="Show Active Agents"
			>
				<Card>
					<CardHeader>
						<CardTitle>Active Agents</CardTitle>
					</CardHeader>
					<CardContent>
						<div class="flex items-center justify-between">
							<span class="text-3xl font-bold"
								>{dashboardSummary?.active_agents ?? 0}</span
							>
							<span class="text-muted-foreground"
								>/ {dashboardSummary?.total_agents ?? 0}</span
							>
						</div>
						<div class="mt-2 text-xs">Online / Total</div>
					</CardContent>
				</Card>
			</button>
			<Card>
				<CardHeader>
					<CardTitle>Running Tasks</CardTitle>
				</CardHeader>
				<CardContent>
					<div class="text-3xl font-bold">{dashboardSummary?.running_tasks ?? 0}</div>
					<div class="mt-2 text-xs">Active Campaigns</div>
				</CardContent>
			</Card>
			<Card>
				<CardHeader>
					<CardTitle>Recently Cracked Hashes</CardTitle>
				</CardHeader>
				<CardContent>
					<div class="text-3xl font-bold">
						{dashboardSummary?.recently_cracked_hashes ?? 0}
					</div>
					<div class="mt-2 text-xs">Last 24h</div>
				</CardContent>
			</Card>
			<Card>
				<CardHeader>
					<CardTitle>Resource Usage</CardTitle>
				</CardHeader>
				<CardContent>
					<!-- TODO: Replace with sparkline chart -->
					<div class="flex h-8 items-end gap-1">
						{#each dashboardSummary?.resource_usage ?? [] as usage, i (i)}
							<div
								class="bg-primary w-2 rounded"
								style="height: {usage.hash_rate / 2}px"
							></div>
						{/each}
					</div>
					<div class="mt-2 text-xs">Hashrate (8h)</div>
				</CardContent>
			</Card>
		</div>

		<!-- Campaign Overview List -->
		<div>
			<h2 class="mb-2 text-xl font-semibold">Campaign Overview</h2>
			{#if campaigns.length === 0}
				<div class="text-muted-foreground py-8 text-center">
					No active campaigns yet. Join or create one to begin.
				</div>
			{:else}
				<AccordionRoot type="multiple" class="w-full">
					{#each campaigns as campaign (campaign.id)}
						<AccordionItem value={String(campaign.id)} class="mb-2">
							<AccordionTrigger class="flex items-center gap-4">
								<span class="font-semibold">{campaign.name}</span>
								<Progress value={campaign.progress} class="mx-4 flex-1" />
								<Badge
									class="ml-2"
									color={(campaign.state === 'running'
										? 'purple'
										: campaign.state === 'completed'
											? 'green'
											: campaign.state === 'error'
												? 'red'
												: 'gray') as string}>{campaign.state}</Badge
								>
								<span class="text-muted-foreground ml-2 text-xs"
									>{campaign.summary}</span
								>
							</AccordionTrigger>
							<AccordionContent>
								<div class="pl-6">
									<!-- No attacks data in summary, placeholder only -->
									<div class="text-muted-foreground text-xs">
										No attack details available.
									</div>
								</div>
							</AccordionContent>
						</AccordionItem>
					{/each}
				</AccordionRoot>
			{/if}
		</div>
	{/if}
</div>

<!-- Agent Status Sheet -->
{#if showAgentSheet}
	<div class="fixed inset-0 z-50 flex justify-end">
		<div
			class="absolute inset-0 bg-black/40"
			role="button"
			tabindex="0"
			on:click={closeAgentSheet}
			on:keydown={(e) => {
				if (e.key === 'Enter' || e.key === ' ') closeAgentSheet();
			}}
			aria-label="Close Agent Sheet"
		></div>
		<SheetRoot class="bg-background flex h-full w-[400px] flex-col shadow-lg">
			<SheetHeader>
				<SheetTitle>Agent Status</SheetTitle>
				<SheetClose />
			</SheetHeader>
			<div class="flex-1 space-y-4 overflow-y-auto p-4">
				<div class="text-muted-foreground text-center">No agent details available.</div>
			</div>
		</SheetRoot>
	</div>
{/if}

<!-- Toast Notification handled by svelte-sonner global Toaster -->
