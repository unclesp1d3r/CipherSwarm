<script lang="ts">
	import { onMount } from 'svelte';
	import axios from 'axios';
	import { Card, CardHeader, CardTitle, CardContent } from '$lib/components/ui/card';
	import {
		Accordion,
		AccordionItem,
		AccordionTrigger,
		AccordionContent
	} from '$lib/components/ui/accordion';
	import { Progress } from '$lib/components/ui/progress';
	import { Badge } from '$lib/components/ui/badge';
	import { TooltipTrigger, TooltipContent } from '$lib/components/ui/tooltip';
	import {
		Table,
		TableHead,
		TableHeader,
		TableBody,
		TableRow,
		TableCell
	} from '$lib/components/ui/table';
	import { Button } from '$lib/components/ui/button';
	import { Pagination } from '$lib/components/ui/pagination';
	import {
		DropdownMenu,
		DropdownMenuTrigger,
		DropdownMenuContent,
		DropdownMenuItem
	} from '$lib/components/ui/dropdown-menu';
	import { goto } from '$app/navigation';
	import CampaignEditorModal from '$lib/components/campaigns/CampaignEditorModal.svelte';
	import CampaignDeleteModal from '$lib/components/campaigns/CampaignDeleteModal.svelte';
	import CrackableUploadModal from '$lib/components/campaigns/CrackableUploadModal.svelte';

	interface Attack {
		id: number;
		type: string;
		language: string;
		length: string;
		settings: string;
		passwords: number;
		complexity: number;
	}

	interface Campaign {
		id: number;
		name: string;
		description?: string;
		priority: number;
		project_id: number;
		hash_list_id: number;
		is_unavailable: boolean;
		state: string;
		progress?: number;
		summary?: string;
		attacks?: Attack[];
		created_at?: string;
		updated_at?: string;
	}

	let campaigns: Campaign[] = [];
	let loading = true;
	let error = '';
	let page = 1;
	let perPage = 10;
	let count = 0;

	// Modal state
	let showEditorModal = false;
	let showDeleteModal = false;
	let showUploadModal = false;
	let editingCampaign: Campaign | null = null;
	let deletingCampaign: Campaign | null = null;

	async function fetchCampaigns() {
		loading = true;
		error = '';
		try {
			const response = await axios.get(
				`/api/v1/web/campaigns?page=${page}&per_page=${perPage}`
			);
			campaigns = response.data.items;
			count = response.data.total;
		} catch (e) {
			error = 'Failed to load campaigns.';
			campaigns = [];
			count = 0;
		} finally {
			loading = false;
		}
	}

	onMount(fetchCampaigns);

	function stateBadge(state: string) {
		switch (state) {
			case 'running':
				return { color: 'bg-purple-600', label: 'Running' };
			case 'completed':
				return { color: 'bg-green-600', label: 'Completed' };
			case 'error':
				return { color: 'bg-red-600', label: 'Error' };
			case 'paused':
				return { color: 'bg-gray-400', label: 'Paused' };
			default:
				return { color: 'bg-gray-200', label: state };
		}
	}

	function handlePageChange(newPage: number) {
		page = newPage;
		fetchCampaigns();
	}

	// Modal handlers
	function openCreateModal() {
		editingCampaign = null;
		showEditorModal = true;
	}

	function openUploadModal() {
		showUploadModal = true;
	}

	function openEditModal(campaign: Campaign) {
		editingCampaign = campaign;
		showEditorModal = true;
	}

	function openDeleteModal(campaign: Campaign) {
		deletingCampaign = campaign;
		showDeleteModal = true;
	}

	function handleCampaignSaved() {
		showEditorModal = false;
		editingCampaign = null;
		fetchCampaigns();
	}

	function handleCampaignDeleted() {
		showDeleteModal = false;
		deletingCampaign = null;
		fetchCampaigns();
	}

	function handleUploadSuccess(event: { uploadId: number }) {
		showUploadModal = false;
		// TODO: Navigate to upload status page or refresh campaigns
		console.log('Upload successful:', event.uploadId);
		fetchCampaigns();
	}

	function closeEditorModal() {
		showEditorModal = false;
		editingCampaign = null;
	}

	function closeDeleteModal() {
		showDeleteModal = false;
		deletingCampaign = null;
	}

	function closeUploadModal() {
		showUploadModal = false;
	}
</script>

<Card class="mx-auto mt-8 w-full max-w-5xl">
	<CardHeader>
		<div class="flex items-center justify-between">
			<CardTitle data-testid="campaigns-title">Campaigns</CardTitle>
			<div class="flex gap-2">
				<Button
					variant="outline"
					data-testid="upload-campaign-button"
					onclick={openUploadModal}
				>
					Upload & Crack
				</Button>
				<Button data-testid="create-campaign-button" onclick={openCreateModal}>
					Create Campaign
				</Button>
			</div>
		</div>
	</CardHeader>
	<CardContent>
		{#if loading}
			<div class="py-8 text-center">Loading campaigns…</div>
		{:else if error}
			<div class="py-8 text-center text-red-600">{error}</div>
		{:else if campaigns.length === 0}
			<div class="py-8 text-center">
				No campaigns found. <Button
					data-testid="empty-state-create-button"
					onclick={openCreateModal}>Create Campaign</Button
				>
			</div>
		{:else}
			<Accordion type="multiple" class="w-full">
				{#each campaigns as campaign (campaign.id)}
					<AccordionItem value={String(campaign.id)} class="border-b">
						<AccordionTrigger class="flex w-full items-center justify-between py-4">
							<div class="flex w-full items-center gap-4">
								<button
									class="flex-1 truncate text-left text-lg font-semibold transition-colors hover:text-blue-600"
									onclick={() => goto(`/campaigns/${campaign.id}`)}
									data-testid="campaign-link-{campaign.id}"
								>
									{campaign.name}
								</button>
								<div class="max-w-xs flex-1">
									<Progress value={campaign.progress} class="h-2" />
								</div>
								<Badge class={stateBadge(campaign.state).color}
									>{stateBadge(campaign.state).label}</Badge
								>
								<span class="text-sm text-gray-500">{campaign.summary}</span>
								<DropdownMenu>
									<DropdownMenuTrigger>
										<Button
											size="icon"
											variant="ghost"
											data-testid="campaign-menu-{campaign.id}"
										>
											<svg
												xmlns="http://www.w3.org/2000/svg"
												fill="none"
												viewBox="0 0 24 24"
												stroke-width="1.5"
												stroke="currentColor"
												class="h-5 w-5"
											>
												<path
													stroke-linecap="round"
													stroke-linejoin="round"
													d="M6.75 12a.75.75 0 110-1.5.75.75 0 010 1.5zm5.25 0a.75.75 0 110-1.5.75.75 0 010 1.5zm5.25 0a.75.75 0 110-1.5.75.75 0 010 1.5z"
												/>
											</svg>
										</Button>
									</DropdownMenuTrigger>
									<DropdownMenuContent>
										<DropdownMenuItem onclick={() => openEditModal(campaign)}>
											Edit Campaign
										</DropdownMenuItem>
										<DropdownMenuItem
											onclick={() => openDeleteModal(campaign)}
											class="text-red-600"
										>
											Delete Campaign
										</DropdownMenuItem>
									</DropdownMenuContent>
								</DropdownMenu>
							</div>
						</AccordionTrigger>
						<AccordionContent class="bg-muted/50">
							<Table class="mt-2 w-full">
								<TableHead>
									<TableRow>
										<TableHeader>Attack</TableHeader>
										<TableHeader>Language</TableHeader>
										<TableHeader>Length</TableHeader>
										<TableHeader>Settings</TableHeader>
										<TableHeader>Passwords to Check</TableHeader>
										<TableHeader>Complexity</TableHeader>
										<TableHeader></TableHeader>
									</TableRow>
								</TableHead>
								<TableBody>
									{#each campaign.attacks || [] as attack (attack.id)}
										<TableRow>
											<TableCell>{attack.type}</TableCell>
											<TableCell>{attack.language}</TableCell>
											<TableCell>{attack.length}</TableCell>
											<TableCell>
												<TooltipTrigger>{attack.settings}</TooltipTrigger>
												<TooltipContent>{attack.settings}</TooltipContent>
											</TableCell>
											<TableCell
												>{attack.passwords.toLocaleString()}</TableCell
											>
											<TableCell>
												<div class="flex space-x-1">
													{#each Array(5) as _, i (i)}
														<span
															class={i < attack.complexity
																? 'h-2 w-2 rounded-full bg-gray-600'
																: 'h-2 w-2 rounded-full bg-gray-200'}
														></span>
													{/each}
												</div>
											</TableCell>
											<TableCell>
												<DropdownMenu>
													<DropdownMenuTrigger>
														<Button size="icon" variant="ghost">
															<svg
																xmlns="http://www.w3.org/2000/svg"
																fill="none"
																viewBox="0 0 24 24"
																stroke-width="1.5"
																stroke="currentColor"
																class="h-5 w-5"
															>
																<path
																	stroke-linecap="round"
																	stroke-linejoin="round"
																	d="M6.75 12a.75.75 0 110-1.5.75.75 0 010 1.5zm5.25 0a.75.75 0 110-1.5.75.75 0 010 1.5zm5.25 0a.75.75 0 110-1.5.75.75 0 010 1.5z"
																/>
															</svg>
														</Button>
													</DropdownMenuTrigger>
													<DropdownMenuContent>
														<DropdownMenuItem>Edit</DropdownMenuItem>
														<DropdownMenuItem
															>Duplicate</DropdownMenuItem
														>
														<DropdownMenuItem>Move Up</DropdownMenuItem>
														<DropdownMenuItem
															>Move Down</DropdownMenuItem
														>
														<DropdownMenuItem class="text-red-600"
															>Remove</DropdownMenuItem
														>
													</DropdownMenuContent>
												</DropdownMenu>
											</TableCell>
										</TableRow>
									{/each}
								</TableBody>
							</Table>
							<div class="mt-4 flex items-center justify-between">
								<Button variant="outline">+ Add Attack…</Button>
								<div class="flex gap-2">
									<Button
										variant="outline"
										class="flex items-center gap-1 text-red-600"
										><svg
											xmlns="http://www.w3.org/2000/svg"
											fill="none"
											viewBox="0 0 24 24"
											stroke-width="1.5"
											stroke="currentColor"
											class="h-5 w-5"
											><path
												stroke-linecap="round"
												stroke-linejoin="round"
												d="M19.5 12h-15"
											/></svg
										>All</Button
									>
									<Button variant="outline">Reset to Default</Button>
									<Button variant="outline">Save/Load</Button>
									<Button variant="outline">Sort by Duration</Button>
								</div>
							</div>
						</AccordionContent>
					</AccordionItem>
				{/each}
			</Accordion>
			{#if count > perPage}
				<div class="mt-4 flex justify-center">
					<Pagination
						count={Math.ceil(count / perPage)}
						{page}
						onPageChange={handlePageChange}
					/>
				</div>
			{/if}
		{/if}
	</CardContent>
</Card>

<!-- Modals -->
<CampaignEditorModal
	bind:open={showEditorModal}
	campaign={editingCampaign}
	on:close={closeEditorModal}
	on:success={handleCampaignSaved}
/>

<CampaignDeleteModal
	bind:open={showDeleteModal}
	campaign={deletingCampaign}
	on:close={closeDeleteModal}
	on:success={handleCampaignDeleted}
/>

<CrackableUploadModal
	bind:open={showUploadModal}
	projectId={1}
	onclose={closeUploadModal}
	onsuccess={handleUploadSuccess}
/>
