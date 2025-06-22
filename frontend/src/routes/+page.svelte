<script lang="ts">
    import { onMount } from 'svelte';
    import Card from '$lib/components/ui/card/card.svelte';
    import CardHeader from '$lib/components/ui/card/card-header.svelte';
    import CardTitle from '$lib/components/ui/card/card-title.svelte';
    import CardContent from '$lib/components/ui/card/card-content.svelte';
    import Progress from '$lib/components/ui/progress/progress.svelte';
    import Badge from '$lib/components/ui/badge/badge.svelte';
    import * as Accordion from '$lib/components/ui/accordion/index.js';
    import SheetRoot from '$lib/components/ui/sheet/sheet-content.svelte';
    import SheetHeader from '$lib/components/ui/sheet/sheet-header.svelte';
    import SheetTitle from '$lib/components/ui/sheet/sheet-title.svelte';
    import SheetClose from '$lib/components/ui/sheet/sheet-close.svelte';
    import { toast } from 'svelte-sonner';
    import { projectsStore } from '$lib/stores/projects.svelte';
    import type { PageData } from './$types';
    import type { DashboardSummary, CampaignItem } from '$lib/types/dashboard';

    let { data }: { data: PageData } = $props();

    // Extract data from SSR
    let dashboardSummary: DashboardSummary = data.dashboard;
    let campaigns: CampaignItem[] = data.campaigns;
    let showAgentSheet = $state(false);

    // Extract context data from SSR
    const context = data.context;
    const { user, active_project, available_projects } = context || {
        user: null,
        active_project: null,
        available_projects: [],
    };

    // Hydrate store with SSR project context data
    $effect(() => {
        if (context && user) {
            projectsStore.hydrateProjectContext(active_project, available_projects, {
                id: user.id,
                email: user.email,
                name: user.name || '',
                role: user.role,
            });
        }
    });

    function openAgentSheet() {
        showAgentSheet = true;
    }
    function closeAgentSheet() {
        showAgentSheet = false;
    }

    function triggerToast(msg: string) {
        toast(msg);
    }

    // Trigger demo toast after component mounts
    onMount(() => {
        setTimeout(() => triggerToast('5 new hashes cracked!'), 2000);
    });
</script>

<svelte:head>
    <title>Dashboard - CipherSwarm</title>
</svelte:head>

<div class="flex flex-col gap-y-6">
    <!-- Top Metric Cards -->
    <div class="grid grid-cols-1 gap-4 md:grid-cols-4">
        <button
            type="button"
            class="h-full w-full cursor-pointer text-left"
            onclick={openAgentSheet}
            aria-label="Show Active Agents">
            <Card>
                <CardHeader>
                    <CardTitle>Active Agents</CardTitle>
                </CardHeader>
                <CardContent>
                    <div class="flex items-center justify-between">
                        <span class="text-3xl font-bold"
                            >{dashboardSummary?.active_agents ?? 0}</span>
                        <span class="text-muted-foreground"
                            >/ {dashboardSummary?.total_agents ?? 0}</span>
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
                        <div class="bg-primary w-2 rounded" style="height: {usage.value / 2}px">
                        </div>
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
            <Accordion.Root type="multiple" class="w-full">
                {#each campaigns as campaign (campaign.id)}
                    <Accordion.Item value={String(campaign.id)} class="mb-2">
                        <Accordion.Trigger class="flex items-center gap-4">
                            <span class="font-semibold">{campaign.name}</span>
                            <Progress value={campaign.progress} class="mx-4 flex-1" />
                            <Badge
                                class="ml-2"
                                color={(campaign.state === 'active'
                                    ? 'purple'
                                    : campaign.state === 'draft'
                                      ? 'yellow'
                                      : campaign.state === 'archived'
                                        ? 'gray'
                                        : 'gray') as string}>{campaign.state}</Badge>
                            <span class="text-muted-foreground ml-2 text-xs"
                                >{campaign.summary}</span>
                        </Accordion.Trigger>
                        <Accordion.Content>
                            <div class="pl-6">
                                <!-- No attacks data in summary, placeholder only -->
                                <div class="text-muted-foreground text-xs">
                                    No attack details available.
                                </div>
                            </div>
                        </Accordion.Content>
                    </Accordion.Item>
                {/each}
            </Accordion.Root>
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
            onclick={closeAgentSheet}
            onkeydown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') closeAgentSheet();
            }}
            aria-label="Close Agent Sheet">
        </div>
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
