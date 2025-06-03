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

	// TODO: Replace with real Svelte stores and WebSocket integration
	let showAgentSheet = false;
	let agents = [
		{
			id: 1,
			name: 'Agent-01',
			status: 'online',
			lastSeen: '1m',
			task: 'Campaign X',
			guessRate: '55 MH/s',
			sparkline: [1, 2, 3, 4, 5, 4, 3, 2, 1]
		},
		{
			id: 2,
			name: 'Agent-02',
			status: 'offline',
			lastSeen: '10m',
			task: 'Idle',
			guessRate: '0 MH/s',
			sparkline: [0, 0, 0, 0, 0, 0, 0, 0, 0]
		}
	];
	let campaigns = [
		{
			id: 1,
			name: 'Password Audit',
			state: 'running',
			progress: 60,
			summary: '3 attacks / 1 running / ETA 3h',
			attacks: [
				{
					id: 11,
					type: 'Dictionary',
					summary: 'rockyou.txt, rules: best64',
					progress: 80,
					eta: '1h',
					state: 'running'
				},
				{
					id: 12,
					type: 'Mask',
					summary: '?d?d?d?d',
					progress: 40,
					eta: '2h',
					state: 'paused'
				}
			]
		},
		{
			id: 2,
			name: 'Sensitive Campaign',
			state: 'completed',
			progress: 100,
			summary: '2 attacks / 0 running',
			attacks: [
				{
					id: 21,
					type: 'Dictionary',
					summary: 'top1000.txt',
					progress: 100,
					eta: '0h',
					state: 'completed'
				}
			]
		}
	];
	let crackedHashes = 42;
	let runningTasks = 3;
	let totalAgents = 5;
	let onlineAgents = 2;
	let resourceUsage = [10, 20, 30, 25, 40, 35, 50, 45]; // mock sparkline

	function openAgentSheet() {
		showAgentSheet = true;
	}
	function closeAgentSheet() {
		showAgentSheet = false;
	}

	function triggerToast(msg: string) {
		toast(msg);
	}

	onMount(() => {
		// TODO: Replace with WebSocket event for cracked hash
		setTimeout(() => triggerToast('5 new hashes cracked!'), 2000);
	});
</script>

<div class="flex flex-col gap-y-6">
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
						<span class="text-3xl font-bold">{onlineAgents}</span>
						<span class="text-muted-foreground">/ {totalAgents}</span>
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
				<div class="text-3xl font-bold">{runningTasks}</div>
				<div class="mt-2 text-xs">Active Campaigns</div>
			</CardContent>
		</Card>
		<Card>
			<CardHeader>
				<CardTitle>Recently Cracked Hashes</CardTitle>
			</CardHeader>
			<CardContent>
				<div class="text-3xl font-bold">{crackedHashes}</div>
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
					{#each resourceUsage as val, i (i)}
						<div class="bg-primary w-2 rounded" style="height: {val / 2}px"></div>
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
								{#each campaign.attacks as attack (attack.id)}
									<div class="flex items-center gap-4 py-2">
										<Badge
											color={(attack.state === 'running'
												? 'purple'
												: attack.state === 'completed'
													? 'green'
													: attack.state === 'error'
														? 'red'
														: 'gray') as string}>{attack.type}</Badge
										>
										<span>{attack.summary}</span>
										<Progress value={attack.progress} class="mx-4 w-32" />
										<span class="text-muted-foreground text-xs"
											>ETA: {attack.eta}</span
										>
									</div>
								{/each}
							</div>
						</AccordionContent>
					</AccordionItem>
				{/each}
			</AccordionRoot>
		{/if}
	</div>
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
				{#each agents as agent (agent.id)}
					<Card>
						<CardHeader class="flex flex-row items-center justify-between">
							<span class="font-semibold">{agent.name}</span>
							<Badge color={(agent.status === 'online' ? 'green' : 'gray') as string}
								>{agent.status}</Badge
							>
						</CardHeader>
						<CardContent>
							<div class="text-muted-foreground mb-1 text-xs">
								Seen {agent.lastSeen} ago
							</div>
							<div class="mb-1">
								Current Task: <span class="font-semibold">{agent.task}</span>
							</div>
							<div class="mb-1">
								Guess Rate: <span class="font-semibold">{agent.guessRate}</span>
							</div>
							<!-- TODO: Replace with sparkline chart -->
							<div class="flex h-6 items-end gap-1">
								{#each agent.sparkline as val, i (i)}
									<div
										class="bg-primary w-1 rounded"
										style="height: {val * 4}px"
									></div>
								{/each}
							</div>
						</CardContent>
					</Card>
				{/each}
			</div>
		</SheetRoot>
	</div>
{/if}

<!-- Toast Notification handled by svelte-sonner global Toaster -->
