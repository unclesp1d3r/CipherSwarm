<script lang="ts">
    import { Badge } from '$lib/components/ui/badge';
    import { Button } from '$lib/components/ui/button';

    interface Props {
        attackId: string;
        enabled: boolean;
        onToggle?: (enabled: boolean) => void;
    }

    let { attackId, enabled = $bindable(), onToggle }: Props = $props();

    async function toggleLiveUpdates() {
        try {
            const response = await fetch(`/api/v1/web/attacks/${attackId}/disable_live_updates`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ enabled: !enabled }),
            });

            if (response.ok) {
                enabled = !enabled;
                onToggle?.(enabled);
            }
        } catch (error) {
            console.error('Failed to toggle live updates:', error);
        }
    }
</script>

<div class="flex items-center gap-2">
    <span class="font-medium text-gray-700 dark:text-gray-200">Live Updates:</span>

    {#if enabled}
        <Badge
            variant="default"
            class="bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">
            Enabled
        </Badge>
        <Button
            variant="destructive"
            size="sm"
            onclick={toggleLiveUpdates}
            class="ml-2 px-3 py-1 text-xs"
            title="Disable live updates for this attack">
            Disable
        </Button>
    {:else}
        <Badge
            variant="destructive"
            class="bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200">
            Disabled
        </Badge>
        <Button
            variant="default"
            size="sm"
            onclick={toggleLiveUpdates}
            class="ml-2 bg-green-600 px-3 py-1 text-xs hover:bg-green-700 focus:ring-green-400"
            title="Enable live updates for this attack">
            Enable
        </Button>
    {/if}
</div>
