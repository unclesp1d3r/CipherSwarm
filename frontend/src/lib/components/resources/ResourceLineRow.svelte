<script lang="ts">
    import { Badge } from '$lib/components/ui/badge';
    import { AlertTriangle } from '@lucide/svelte';
    import type { ResourceLine } from '$lib/schemas/resources';

    export let line: ResourceLine;
</script>

<div
    class="hover:bg-muted/50 flex items-start gap-2 rounded-md p-2 transition-colors"
    data-line-id={line.id}
>
    <span class="text-muted-foreground min-w-12 text-right font-mono text-xs">
        {line.index}:
    </span>
    <span class="flex-1 font-mono text-sm break-all">
        {line.content}
    </span>
    {#if !line.valid && line.error_message}
        <div class="flex items-center gap-1">
            <AlertTriangle class="text-destructive h-4 w-4" />
            <Badge variant="destructive" class="text-xs">
                {line.error_message}
            </Badge>
        </div>
    {/if}
</div>
