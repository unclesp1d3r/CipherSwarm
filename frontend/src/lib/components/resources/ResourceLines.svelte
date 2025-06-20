<script lang="ts">
    import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/ui/card';
    import { Badge } from '$lib/components/ui/badge';
    import { Skeleton } from '$lib/components/ui/skeleton';
    import { FileText, List } from '@lucide/svelte';
    import ResourceLineRow from './ResourceLineRow.svelte';
    import type { ResourceDetailResponse, ResourceLine } from '$lib/schemas/resources';

    export let resource: ResourceDetailResponse | null = null;
    export let lines: ResourceLine[] = [];
    export let loading = false;

    function formatResourceType(type: string): string {
        return type.replace('_', ' ').replace(/\b\w/g, (l) => l.toUpperCase());
    }

    function getResourceTypeVariant(
        type: string
    ): 'default' | 'secondary' | 'destructive' | 'outline' {
        switch (type) {
            case 'mask_list':
                return 'default';
            case 'rule_list':
                return 'secondary';
            case 'word_list':
                return 'outline';
            case 'charset':
                return 'destructive';
            case 'dynamic_word_list':
                return 'secondary';
            default:
                return 'outline';
        }
    }
</script>

{#if loading}
    <Card>
        <CardHeader>
            <Skeleton class="h-6 w-64" />
        </CardHeader>
        <CardContent>
            <div class="space-y-2">
                {#each Array(10) as _, i (i)}
                    <Skeleton class="h-6 w-full" />
                {/each}
            </div>
        </CardContent>
    </Card>
{:else if resource}
    <Card>
        <CardHeader>
            <CardTitle class="flex items-center gap-2">
                <List class="h-5 w-5" />
                Lines: {resource.file_name}
                <Badge variant={getResourceTypeVariant(resource.resource_type)} class="ml-2">
                    {formatResourceType(resource.resource_type)}
                </Badge>
            </CardTitle>
        </CardHeader>
        <CardContent>
            {#if lines.length > 0}
                <div class="max-h-96 space-y-1 overflow-y-auto">
                    {#each lines as line (line.id)}
                        <ResourceLineRow {line} />
                    {/each}
                </div>
            {:else}
                <div class="text-muted-foreground py-8 text-center">
                    <FileText class="mx-auto mb-4 h-12 w-12 opacity-50" />
                    <p>No lines available for this resource.</p>
                </div>
            {/if}
        </CardContent>
    </Card>
{/if}
