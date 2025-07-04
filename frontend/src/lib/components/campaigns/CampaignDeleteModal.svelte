<script lang="ts">
    import { Alert, AlertDescription } from '$lib/components/ui/alert';
    import { Badge } from '$lib/components/ui/badge';
    import { Button } from '$lib/components/ui/button';
    import * as Dialog from '$lib/components/ui/dialog';
    import axios, { isAxiosError } from 'axios';
    import { createEventDispatcher } from 'svelte';

    interface Campaign {
        id: number;
        name: string;
        description?: string;
        priority: number;
        project_id: number;
        hash_list_id: number;
        is_unavailable: boolean;
        state?: string;
        created_at?: string;
        updated_at?: string;
    }

    export let open = false;
    export let campaign: Campaign | null = null;

    const dispatch = createEventDispatcher<{
        close: void;
        success: void;
    }>();

    let loading = false;
    let error = '';

    function handleClose() {
        open = false;
        error = '';
        dispatch('close');
    }

    async function handleDelete() {
        if (!campaign) return;

        loading = true;
        error = '';

        try {
            await axios.delete(`/api/v1/web/campaigns/${campaign.id}`);
            dispatch('success');
            handleClose();
        } catch (e) {
            if (isAxiosError(e)) {
                switch (e.response?.status) {
                    case 404:
                        error = 'Campaign not found.';
                        break;
                    case 403:
                        error = 'You do not have permission to delete this campaign.';
                        break;
                    case 409:
                        error = 'Cannot delete campaign that is currently running.';
                        break;
                    default:
                        error = 'Failed to delete campaign.';
                }
            } else {
                error = 'An unexpected error occurred.';
            }
        } finally {
            loading = false;
        }
    }

    function getStateVariant(state: string | undefined) {
        switch (state) {
            case 'running':
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

{#if campaign}
    <Dialog.Root bind:open onOpenChange={handleClose}>
        <Dialog.Content class="sm:max-w-md">
            <Dialog.Header>
                <Dialog.Title data-testid="modal-title">Delete Campaign</Dialog.Title>
                <Dialog.Description>
                    Are you sure you want to delete this campaign? This action cannot be undone.
                </Dialog.Description>
            </Dialog.Header>

            {#if error}
                <Alert variant="destructive">
                    <AlertDescription data-testid="error-message">{error}</AlertDescription>
                </Alert>
            {/if}

            <div class="space-y-3">
                <div class="rounded border p-3">
                    <div class="flex items-center justify-between">
                        <h4 class="font-medium" data-testid="campaign-name">{campaign.name}</h4>
                        {#if campaign.state}
                            <Badge
                                variant={getStateVariant(campaign.state)}
                                data-testid="campaign-state">
                                {campaign.state}
                            </Badge>
                        {/if}
                    </div>
                    <p class="mt-1 text-sm text-gray-600" data-testid="campaign-description">
                        {campaign.description || 'No description'}
                    </p>
                </div>

                {#if campaign.state === 'running'}
                    <Alert class="mt-3" variant="destructive">
                        <AlertDescription data-testid="running-warning">
                            Warning: This campaign is currently running. Deleting it will stop all
                            active tasks.
                        </AlertDescription>
                    </Alert>
                {/if}
            </div>

            <Dialog.Footer class="flex gap-2">
                <Button
                    type="button"
                    variant="outline"
                    onclick={handleClose}
                    disabled={loading}
                    data-testid="cancel-button">
                    Cancel
                </Button>
                <Button
                    type="button"
                    variant="destructive"
                    onclick={handleDelete}
                    disabled={loading}
                    data-testid="delete-button">
                    {#if loading}
                        Deleting...
                    {:else}
                        Delete Campaign
                    {/if}
                </Button>
            </Dialog.Footer>
        </Dialog.Content>
    </Dialog.Root>
{/if}
