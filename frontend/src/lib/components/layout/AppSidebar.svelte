<script lang="ts">
    import NightModeToggleButton from './NightModeToggleButton.svelte';
    import UserMenu from './UserMenu.svelte';
    import ProjectSelector from '$lib/components/layout/ProjectSelector.svelte';
    import * as Sidebar from '$lib/components/ui/sidebar/index.js';
    import { projectsStore } from '$lib/stores/projects.svelte';

    // Get user context from store
    const user = $derived(projectsStore.contextUser);
    const userRole = $derived(user?.role || 'user');

    const navLinks = [
        {
            label: 'Dashboard',
            href: '/',
            icon: 'dashboard',
            roles: ['user', 'admin', 'project_admin', 'analyst', 'operator'],
        },
        {
            label: 'Campaigns',
            href: '/campaigns',
            icon: 'campaign',
            roles: ['user', 'admin', 'project_admin', 'analyst', 'operator'],
        },
        {
            label: 'Attacks',
            href: '/attacks',
            icon: 'zap',
            roles: ['user', 'admin', 'project_admin', 'analyst', 'operator'],
        },
        {
            label: 'Agents',
            href: '/agents',
            icon: 'cpu',
            roles: ['user', 'admin', 'project_admin', 'analyst', 'operator'],
        },
        {
            label: 'Resources',
            href: '/resources',
            icon: 'database',
            roles: ['user', 'admin', 'project_admin', 'analyst', 'operator'],
        },
        { label: 'Users', href: '/users', icon: 'users', roles: ['admin'] },
        {
            label: 'Settings',
            href: '/settings',
            icon: 'settings',
            roles: ['user', 'admin', 'project_admin', 'analyst', 'operator'],
        },
    ];

    function isActive(href: string, current: string) {
        return current === href || (href !== '/' && current.startsWith(href));
    }
</script>

<Sidebar.Root>
    <Sidebar.Header>
        <div class="flex w-full items-center justify-between">
            <NightModeToggleButton />
            <UserMenu />
        </div>
    </Sidebar.Header>
    <Sidebar.Content>
        <Sidebar.Menu>
            {#each navLinks as link (link.href)}
                {#if link.roles.includes(userRole)}
                    <Sidebar.MenuItem>
                        <a href={link.href} class="flex w-full items-center gap-2">
                            <span class="i-lucide-{link.icon} size-4"></span>
                            <span>{link.label}</span>
                        </a>
                    </Sidebar.MenuItem>
                {/if}
            {/each}
        </Sidebar.Menu>
    </Sidebar.Content>
    <Sidebar.Footer>
        <ProjectSelector />
    </Sidebar.Footer>
</Sidebar.Root>
