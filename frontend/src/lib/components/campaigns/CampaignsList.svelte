<script lang="ts">
	// Svelte 5 runes syntax (let, $derived, etc.)
	import Card from '../ui/card/card.svelte';
	import CardHeader from '../ui/card/card-header.svelte';
	import CardTitle from '../ui/card/card-title.svelte';
	import CardContent from '../ui/card/card-content.svelte';
	import Badge from '../ui/badge/badge.svelte';
	import Progress from '../ui/progress/progress.svelte';
	import Accordion from '../ui/accordion/accordion-root.svelte';
	import AccordionItem from '../ui/accordion/accordion-item.svelte';
	import Button from '../ui/button/button.svelte';
	import CogIcon from '@lucide/svelte/icons/cog';

	export let campaigns = [
		{
			id: '1',
			name: 'Fall PenTest Roundup',
			state: 'running',
			progress: 0.42,
			summary: '⚡ 3 attacks / 1 running / ETA 3h',
			attacks: [
				{
					id: 'a1',
					type: 'Brute-force',
					language: 'English',
					length: '1-4',
					settings: 'Lowercase, Uppercase, Numbers, Symbols',
					passwords: '78,914,410',
					complexity: 4
				}
			]
		},
		{
			id: '2',
			name: 'Sensitive Campaign',
			state: 'completed',
			progress: 1.0,
			summary: '✔️ 2 attacks / 2 completed',
			attacks: []
		}
	];

	export let error = '';
	let loading = false;
</script>

<Card>
	<CardHeader>
		<CardTitle>Campaigns</CardTitle>
	</CardHeader>
	<CardContent>
		{#if loading}
			<div class="py-8 text-center">Loading campaigns...</div>
		{:else if error}
			<div class="py-8 text-center text-red-600">{error}</div>
		{:else if campaigns.length === 0}
			<div class="py-8 text-center">
				No campaigns found. Create a new campaign to get started.
			</div>
		{:else}
			<Accordion type="multiple">
				{#each campaigns as campaign (campaign.id)}
					<AccordionItem value={campaign.id}>
						<div
							class="grid grid-cols-6 items-center gap-4 border-b border-gray-200 py-2 dark:border-gray-700"
						>
							<div class="font-semibold">{campaign.name}</div>
							<div><Progress value={campaign.progress * 100} /></div>
							<div>
								{#if campaign.state === 'running'}
									<Badge color="purple">Running</Badge>
								{:else if campaign.state === 'completed'}
									<Badge color="green">Completed</Badge>
								{:else if campaign.state === 'error'}
									<Badge color="red">Error</Badge>
								{:else if campaign.state === 'paused'}
									<Badge color="gray">Paused</Badge>
								{:else}
									<Badge color="gray">Unknown</Badge>
								{/if}
							</div>
							<div>{campaign.summary}</div>
							<div>
								<Button variant="ghost" size="icon"><CogIcon size={18} /></Button>
							</div>
							<div>
								<Button variant="outline" size="sm">Expand</Button>
							</div>
						</div>
						{#if campaign.attacks && campaign.attacks.length > 0}
							<div class="pl-4">
								<div
									class="grid grid-cols-6 gap-2 py-2 text-xs font-medium text-gray-500 dark:text-gray-400"
								>
									<div>Attack</div>
									<div>Language</div>
									<div>Length</div>
									<div>Settings</div>
									<div>Passwords to Check</div>
									<div>Complexity</div>
								</div>
								{#each campaign.attacks as attack (attack.id)}
									<div
										class="grid grid-cols-6 items-center gap-2 border-b border-gray-100 py-1 dark:border-gray-800"
									>
										<div>{attack.type}</div>
										<div>{attack.language}</div>
										<div>{attack.length}</div>
										<div class="text-blue-600 hover:underline">
											{attack.settings}
										</div>
										<div>{attack.passwords}</div>
										<div>
											<div class="flex space-x-1">
												{#each Array(5) as _, i (i)}
													<span
														class="h-2 w-2 rounded-full {i <
														attack.complexity
															? 'bg-gray-600'
															: 'bg-gray-200'}"
													></span>
												{/each}
											</div>
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</AccordionItem>
				{/each}
			</Accordion>
			<div class="mt-4 flex gap-2">
				<Button variant="outline">+ Add Campaign</Button>
				<Button variant="outline" color="red">Remove All</Button>
			</div>
		{/if}
	</CardContent>
</Card>

<style>
	/***** Add any component-specific styles here if needed *****/
</style>
