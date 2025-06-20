<script lang="ts">
    import * as Sidebar from '$lib/components/ui/sidebar/index.js';
    import { page } from '$app/stores';
    import ProjectSelector from '$lib/components/layout/ProjectSelector.svelte';
    import { Button } from '$lib/components/ui/button/index.js';
    import { toggleMode } from 'mode-watcher';
    import SunIcon from '@lucide/svelte/icons/sun';
    import MoonIcon from '@lucide/svelte/icons/moon';

    // TODO: Replace with real session/role store
    const userRole = 'admin'; // stub

    const navLinks = [
        {
            label: 'Dashboard',
            href: '/',
            icon: 'dashboard',
            roles: ['user', 'admin', 'project_admin']
        },
        {
            label: 'Campaigns',
            href: '/campaigns',
            icon: 'campaign',
            roles: ['user', 'admin', 'project_admin']
        },
        {
            label: 'Attacks',
            href: '/attacks',
            icon: 'zap',
            roles: ['user', 'admin', 'project_admin']
        },
        {
            label: 'Agents',
            href: '/agents',
            icon: 'cpu',
            roles: ['user', 'admin', 'project_admin']
        },
        {
            label: 'Resources',
            href: '/resources',
            icon: 'database',
            roles: ['user', 'admin', 'project_admin']
        },
        { label: 'Users', href: '/users', icon: 'users', roles: ['admin'] },
        {
            label: 'Settings',
            href: '/settings',
            icon: 'settings',
            roles: ['user', 'admin', 'project_admin']
        }
    ];

    function isActive(href: string, current: string) {
        return current === href || (href !== '/' && current.startsWith(href));
    }
</script>

<Button onclick={toggleMode} variant="outline" size="icon">
    <SunIcon
        class="h-[1.2rem] w-[1.2rem] scale-100 rotate-0 transition-all dark:scale-0 dark:-rotate-90"
    />
    <MoonIcon
        class="absolute h-[1.2rem] w-[1.2rem] scale-0 rotate-90 transition-all dark:scale-100 dark:rotate-0"
    />
    <span class="sr-only">Toggle theme</span>
</Button>
