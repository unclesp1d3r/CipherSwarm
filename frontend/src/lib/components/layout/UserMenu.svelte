<script lang="ts">
    import * as DropdownMenu from '$lib/components/ui/dropdown-menu/index.js';
    import * as Avatar from '$lib/components/ui/avatar/index.js';
    import * as AlertDialog from '$lib/components/ui/alert-dialog/index.js';
    import { Button } from '$lib/components/ui/button/index.js';
    import { authStore } from '$lib/stores/auth.svelte.js';
    import { projectsStore } from '$lib/stores/projects.svelte.js';
    import UserIcon from '@lucide/svelte/icons/user';
    import LogOutIcon from '@lucide/svelte/icons/log-out';
    import SettingsIcon from '@lucide/svelte/icons/settings';

    // Get user context from store
    const user = $derived(projectsStore.contextUser);

    // State for controlling the logout confirmation dialog
    let showLogoutDialog = $state(false);

    // Function to get user initials for avatar fallback
    function getUserInitials(name: string): string {
        return name
            .split(' ')
            .map((part) => part.charAt(0).toUpperCase())
            .slice(0, 2)
            .join('');
    }

    // Show logout confirmation dialog
    function showLogoutConfirmation() {
        showLogoutDialog = true;
    }

    // Handle confirmed logout
    async function handleConfirmedLogout() {
        showLogoutDialog = false;
        await authStore.logout();
    }

    // Handle cancelled logout
    function handleCancelLogout() {
        showLogoutDialog = false;
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
                onclick={showLogoutConfirmation}
                variant="destructive"
                data-testid="user-menu-logout"
            >
                <LogOutIcon class="mr-2 h-4 w-4" />
                Logout
            </DropdownMenu.Item>
        </DropdownMenu.Content>
    </DropdownMenu.Root>

    <!-- Logout Confirmation Dialog -->
    <AlertDialog.Root bind:open={showLogoutDialog}>
        <AlertDialog.Content data-testid="logout-confirmation-dialog">
            <AlertDialog.Header>
                <AlertDialog.Title>Confirm Logout</AlertDialog.Title>
                <AlertDialog.Description>
                    Are you sure you want to log out? You will need to sign in again to access your
                    account.
                </AlertDialog.Description>
            </AlertDialog.Header>
            <AlertDialog.Footer>
                <AlertDialog.Cancel onclick={handleCancelLogout} data-testid="logout-cancel-button">
                    Cancel
                </AlertDialog.Cancel>
                <AlertDialog.Action
                    onclick={handleConfirmedLogout}
                    class="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                    data-testid="logout-confirm-button"
                >
                    Log Out
                </AlertDialog.Action>
            </AlertDialog.Footer>
        </AlertDialog.Content>
    </AlertDialog.Root>
{/if}
