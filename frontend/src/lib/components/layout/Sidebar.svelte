<script lang="ts">
	import SidebarPrimitive from '$lib/components/ui/sidebar/sidebar.svelte';
	import SidebarMenu from '$lib/components/ui/sidebar/sidebar-menu.svelte';
	import SidebarMenuItem from '$lib/components/ui/sidebar/sidebar-menu-item.svelte';
	import SidebarMenuButton from '$lib/components/ui/sidebar/sidebar-menu-button.svelte';
	import { page } from '$app/stores';

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

<SidebarPrimitive>
	<SidebarMenu>
		{#each navLinks as link (link.href)}
			{#if link.roles.includes(userRole)}
				<SidebarMenuItem>
					<a href={link.href} class="flex w-full items-center gap-2">
						<!-- TODO: Replace with real icons -->
						<span class="i-lucide-{link.icon} size-4"></span>
						<span>{link.label}</span>
					</a>
				</SidebarMenuItem>
			{/if}
		{/each}
	</SidebarMenu>
</SidebarPrimitive>
