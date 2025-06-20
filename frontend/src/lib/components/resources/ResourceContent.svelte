<script lang="ts">
    import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/ui/card';
    import { Badge } from '$lib/components/ui/badge';
    import { Button } from '$lib/components/ui/button';
    import { Textarea } from '$lib/components/ui/textarea';
    import { Alert, AlertDescription } from '$lib/components/ui/alert';
    import { Skeleton } from '$lib/components/ui/skeleton';
    import { FileText, Save, AlertTriangle, Lock } from '@lucide/svelte';
    import { createEventDispatcher } from 'svelte';

    interface Resource {
        id: string;
        file_name: string;
        resource_type: string;
    }

    export let resource: Resource | null = null;
    export let content = '';
    export let editable = true;
    export let loading = false;
    export let saving = false;
    export let error: string | null = null;

    const dispatch = createEventDispatcher<{
        save: { content: string };
    }>();

    let editedContent = content;

    $: editedContent = content;

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

    function handleSave() {
        dispatch('save', { content: editedContent });
    }

    $: hasChanges = editedContent !== content;
</script>

{#if loading}
    <Card>
        <CardHeader>
            <Skeleton class="h-6 w-64" />
        </CardHeader>
        <CardContent>
            <Skeleton class="h-64 w-full" />
        </CardContent>
    </Card>
{:else if resource}
    <Card>
        <CardHeader>
            <CardTitle class="flex items-center gap-2">
                <FileText class="h-5 w-5" />
                Edit Resource: {resource.file_name}
                <Badge variant={getResourceTypeVariant(resource.resource_type)} class="ml-2">
                    {formatResourceType(resource.resource_type)}
                </Badge>
            </CardTitle>
        </CardHeader>
        <CardContent class="space-y-4">
            {#if error}
                <Alert variant="destructive">
                    <AlertTriangle class="h-4 w-4" />
                    <AlertDescription>{error}</AlertDescription>
                </Alert>
            {/if}

            <div class="space-y-2">
                <Textarea
                    bind:value={editedContent}
                    disabled={!editable || saving}
                    class="min-h-64 resize-y font-mono text-sm"
                    placeholder="Resource content..."
                />

                {#if !editable}
                    <Alert>
                        <Lock class="h-4 w-4" />
                        <AlertDescription>
                            Editing is disabled for this resource (read-only or too large).
                        </AlertDescription>
                    </Alert>
                {/if}
            </div>

            {#if editable}
                <div class="flex justify-end gap-2">
                    <Button
                        variant="outline"
                        disabled={!hasChanges || saving}
                        onclick={() => (editedContent = content)}
                    >
                        Reset
                    </Button>
                    <Button disabled={!hasChanges || saving} onclick={handleSave}>
                        {#if saving}
                            <div
                                class="mr-2 h-4 w-4 animate-spin rounded-full border-b-2 border-white"
                            ></div>
                        {:else}
                            <Save class="mr-2 h-4 w-4" />
                        {/if}
                        Save Changes
                    </Button>
                </div>
            {/if}
        </CardContent>
    </Card>
{/if}
