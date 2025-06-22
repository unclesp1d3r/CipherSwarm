<script lang="ts">
    import { Badge } from '$lib/components/ui/badge';
    import { AlertTriangle } from '@lucide/svelte';
    import type { ResourceLine } from '$lib/schemas/resources';

    export let line: ResourceLine;
</script>

<div
    class="hover:bg-muted/50 flex items-start gap-2 rounded-md p-2 transition-colors"
    data-line-id={line.id}>
    <span class="text-muted-foreground min-w-12 text-right font-mono text-xs">
        {line.line_number}:
    </span>
    <span class="flex-1 font-mono text-sm break-all">
        {line.content}
    </span>
    <!-- Error display removed - not available in current schema -->
</div>
