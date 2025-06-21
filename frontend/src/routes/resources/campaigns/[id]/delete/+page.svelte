<script lang="ts">
    import { goto } from '$app/navigation';
    import { superForm } from 'sveltekit-superforms';
    import { zodClient } from 'sveltekit-superforms/adapters';
    import { Button } from '$lib/components/ui/button';
    import { Dialog, DialogContent, DialogHeader, DialogTitle } from '$lib/components/ui/dialog';
    import { Alert, AlertDescription } from '$lib/components/ui/alert';
    import { Badge } from '$lib/components/ui/badge';
    import { deleteCampaignSchema } from './schema';
    import type { PageData } from './$types';

    let { data }: { data: PageData } = $props();

    const { form, enhance, submitting } = superForm(data.form, {
        validators: zodClient(deleteCampaignSchema),
        onResult: ({ result }) => {
            if (result.type === 'redirect') {
                // Form action will handle the redirect
                return;
            }
        },
    });

    function handleClose() {
        goto('/campaigns');
    }

    function handleKeydown(event: KeyboardEvent) {
        if (event.key === 'Escape') {
            handleClose();
        }
    }

    function getStateVariant(state: string | undefined) {
        switch (state) {
            case 'running':
            case 'active':
                return 'destructive';
            case 'completed':
                return 'default';
            case 'paused':
                return 'secondary';
            default:
                return 'outline';
        }
    }
</script>

<svelte:window onkeydown={handleKeydown} />

<Dialog open={true} onOpenChange={handleClose}>
    <DialogContent class="sm:max-w-md" data-testid="campaign-delete-modal">
        <DialogHeader>
            <DialogTitle data-testid="modal-title">Delete Campaign</DialogTitle>
        </DialogHeader>

        <form method="POST" use:enhance>
            <div class="space-y-4">
                <p class="text-sm text-gray-600">
                    Are you sure you want to delete this campaign? This action cannot be undone.
                </p>

                <div class="rounded border p-3">
                    <div class="flex items-center justify-between">
                        <h4 class="font-medium" data-testid="campaign-name">
                            {data.campaign.name}
                        </h4>
                        {#if data.campaign.status}
                            <Badge
                                variant={getStateVariant(data.campaign.status)}
                                data-testid="campaign-status">
                                {data.campaign.status}
                            </Badge>
                        {/if}
                    </div>
                    <p class="mt-1 text-sm text-gray-600" data-testid="campaign-description">
                        {data.campaign.description || 'No description'}
                    </p>
                </div>

                {#if data.attackCount > 0 || data.resourceCount > 0}
                    <Alert class="mt-3" variant="destructive">
                        <AlertDescription data-testid="impact-warning">
                            Warning: This campaign has {data.attackCount} attack{data.attackCount !==
                            1
                                ? 's'
                                : ''}
                            and {data.resourceCount} associated resource{data.resourceCount !== 1
                                ? 's'
                                : ''}. Deleting it will archive all associated data.
                        </AlertDescription>
                    </Alert>
                {/if}

                {#if data.campaign.status === 'active'}
                    <Alert class="mt-3" variant="destructive">
                        <AlertDescription data-testid="running-warning">
                            Warning: This campaign is currently running. Deleting it will stop all
                            active tasks.
                        </AlertDescription>
                    </Alert>
                {/if}

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
                        disabled={$submitting}
                        data-testid="cancel-button">
                        Cancel
                    </Button>
                    <Button
                        type="submit"
                        variant="destructive"
                        disabled={$submitting}
                        data-testid="delete-button">
                        {$submitting ? 'Deleting...' : 'Delete Campaign'}
                    </Button>
                </div>
            </div>
        </form>
    </DialogContent>
</Dialog>
