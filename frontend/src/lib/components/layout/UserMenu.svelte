<script lang="ts">
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu/index.js';
	import * as Avatar from '$lib/components/ui/avatar/index.js';
	import { Button } from '$lib/components/ui/button/index.js';
	import { authStore } from '$lib/stores/auth.svelte.js';
	import { projectsStore } from '$lib/stores/projects.svelte.js';
	import UserIcon from '@lucide/svelte/icons/user';
	import LogOutIcon from '@lucide/svelte/icons/log-out';
	import SettingsIcon from '@lucide/svelte/icons/settings';

	// Get user context from store
	const user = $derived(projectsStore.contextUser);

	// Function to get user initials for avatar fallback
	function getUserInitials(name: string): string {
		return name
			.split(' ')
			.map((part) => part.charAt(0).toUpperCase())
			.slice(0, 2)
			.join('');
	}

	// Handle logout
	async function handleLogout() {
		await authStore.logout();
	}
</script>

{#if user}
	<DropdownMenu.Root>
		<DropdownMenu.Trigger>
			{#snippet child({ props })}
				<Button
					{...props}
					variant="ghost"
					size="sm"
					class="h-8 w-8 rounded-full p-0"
					data-testid="user-menu-trigger"
				>
					<Avatar.Root class="h-8 w-8">
						<Avatar.Fallback class="text-xs">
							{getUserInitials(user.name)}
						</Avatar.Fallback>
					</Avatar.Root>
					<span class="sr-only">Open user menu</span>
				</Button>
			{/snippet}
		</DropdownMenu.Trigger>
		<DropdownMenu.Content align="end" class="w-56">
			<DropdownMenu.Label class="font-normal">
				<div class="flex flex-col space-y-1">
					<p class="text-sm leading-none font-medium">{user.name}</p>
					<p class="text-muted-foreground text-xs leading-none">{user.email}</p>
				</div>
			</DropdownMenu.Label>
			<DropdownMenu.Separator />
			<DropdownMenu.Item>
				{#snippet child({ props })}
					<a
						{...props}
						href="/settings"
						class="cursor-pointer"
						data-testid="user-menu-settings"
					>
						<SettingsIcon class="mr-2 h-4 w-4" />
						Settings
					</a>
				{/snippet}
			</DropdownMenu.Item>
			<DropdownMenu.Separator />
			<DropdownMenu.Item
				onclick={handleLogout}
				variant="destructive"
				data-testid="user-menu-logout"
			>
				<LogOutIcon class="mr-2 h-4 w-4" />
				Logout
			</DropdownMenu.Item>
		</DropdownMenu.Content>
	</DropdownMenu.Root>
{/if}
