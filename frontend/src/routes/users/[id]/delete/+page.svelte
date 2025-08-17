<script lang="ts">
    import { goto } from '$app/navigation';
    import { page } from '$app/stores';
    import { superForm } from 'sveltekit-superforms';
    import { zodClient } from 'sveltekit-superforms/adapters';
    import { Button } from '$lib/components/ui/button';
    import { Dialog, DialogContent, DialogHeader, DialogTitle } from '$lib/components/ui/dialog';
    import { deleteUserSchema } from './schema';
    import type { PageData } from './$types';

    let { data }: { data: PageData } = $props();

    const { form, enhance, submitting } = superForm(data.form, {
        validators: zodClient(deleteUserSchema),
        onResult: ({ result }) => {
            if (result.type === 'redirect') {
                // Form action will handle the redirect
                return;
            }
        },
    });

    function handleClose() {
        goto('/users');
    }

    function handleKeydown(event: KeyboardEvent) {
        if (event.key === 'Escape') {
            handleClose();
        }
    }
</script>

<svelte:window onkeydown={handleKeydown} />

<Dialog open={true} onOpenChange={handleClose}>
    <DialogContent class="sm:max-w-md" data-testid="user-delete-modal">
        <DialogHeader>
            <DialogTitle>Deactivate User</DialogTitle>
        </DialogHeader>

        <form method="POST" use:enhance>
            <div class="space-y-4">
                <p class="text-sm text-gray-600">
                    Are you sure you want to deactivate the user <strong>{data.user.name}</strong>
                    ({data.user.email})?
                </p>

                <p class="text-sm text-gray-600">
                    This will deactivate the user account, preventing them from logging in. This
                    action can be reversed by reactivating the user.
                </p>

                {#if $form.message}
                    <div class="text-sm text-red-600" data-testid="error-message">
                        {$form.message}
                    </div>
                {/if}

                <div class="flex justify-end gap-2">
                    <Button
                        type="button"
                        variant="outline"
                        onclick={handleClose}
                        data-testid="cancel-button">
                        Cancel
                    </Button>
                    <Button
                        type="submit"
                        variant="destructive"
                        disabled={$submitting}
                        data-testid="confirm-delete-button">
                        {$submitting ? 'Deactivating...' : 'Deactivate User'}
                    </Button>
                </div>
            </div>
        </form>
    </DialogContent>
</Dialog>
