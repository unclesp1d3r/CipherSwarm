<script lang="ts">
    import { page } from '$app/state';
    import * as Breadcrumb from '$lib/components/ui/breadcrumb/index.js';
    import { Home } from 'lucide-svelte';

    // Route mapping for breadcrumb labels
    const routeLabels: Record<string, string> = {
        campaigns: 'Campaigns',
        attacks: 'Attacks',
        agents: 'Agents',
        resources: 'Resources',
        users: 'Users',
        settings: 'Settings',
        projects: 'Projects',
    };

    // Generate breadcrumb items from current path
    const breadcrumbItems = $derived(
        (() => {
            const path = page.url.pathname;
            const segments = path.split('/').filter(Boolean);

            // Always start with home/dashboard
            const items: Array<{ href: string; label: string; isLast: boolean }> = [
                { href: '/', label: 'Dashboard', isLast: false },
            ];

            // Add breadcrumb items for each path segment
            segments.forEach((segment, index) => {
                const isLast = index === segments.length - 1;
                const href = '/' + segments.slice(0, index + 1).join('/');
                let label = routeLabels[segment] || segment;

                // Handle special cases for edit routes and IDs
                if (segment === 'edit') {
                    label = 'Edit';
                } else if (segment === 'new') {
                    label = 'New';
                } else if (/^\d+$/.test(segment) || /^[0-9a-f-]{36}$/i.test(segment)) {
                    // ID segments (numeric or UUID) - use generic label
                    label = 'Details';
                }

                items.push({ href, label, isLast });
            });

            return items;
        })()
    );
</script>

<nav class="mb-4" aria-label="Breadcrumb">
    <Breadcrumb.Root>
        <Breadcrumb.List>
            {#each breadcrumbItems as item, index (item.href)}
                <Breadcrumb.Item>
                    {#if item.isLast}
                        <Breadcrumb.Page>{item.label}</Breadcrumb.Page>
                    {:else}
                        <Breadcrumb.Link href={item.href} class="flex items-center">
                            {#if index === 0}
                                <Home class="mr-1 h-4 w-4" />
                            {/if}
                            {item.label}
                        </Breadcrumb.Link>
                    {/if}
                </Breadcrumb.Item>

                {#if !item.isLast}
                    <Breadcrumb.Separator />
                {/if}
            {/each}
        </Breadcrumb.List>
    </Breadcrumb.Root>
</nav>
