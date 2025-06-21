<script lang="ts">
    import { Badge } from '$lib/components/ui/badge';
    import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/ui/card';
    import {
        Table,
        TableBody,
        TableCell,
        TableHead,
        TableHeader,
        TableRow,
    } from '$lib/components/ui/table';
    import { Skeleton } from '$lib/components/ui/skeleton';
    import { Alert, AlertDescription } from '$lib/components/ui/alert';
    import { FileText, Calendar, Hash, Database, Link } from '@lucide/svelte';
    import type { ResourceDetailResponse, AttackBasic } from '$lib/schemas/resources';

    export let resource: ResourceDetailResponse | null = null;
    export let attacks: AttackBasic[] = [];
    export let loading = false;
    export let error: string | null = null;

    function formatFileSize(bytes: number | null): string {
        if (!bytes) return '0 KB';
        const kb = Math.round(bytes / 1024);
        if (kb > 1024) {
            const mb = Math.round(kb / 1024);
            return `${mb.toLocaleString()} MB`;
        }
        return `${kb.toLocaleString()} KB`;
    }

    function formatDate(dateStr: string | null): string {
        if (!dateStr) return 'N/A';
        return new Date(dateStr).toLocaleDateString('en-US', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
        });
    }

    function formatResourceType(type: string): string {
        return type.replace('_', ' ').replace(/\b\w/g, (l) => l.toUpperCase());
    }

    function getStateVariant(state: string): 'default' | 'secondary' | 'destructive' | 'outline' {
        switch (state.toLowerCase()) {
            case 'running':
                return 'default';
            case 'completed':
                return 'secondary';
            case 'failed':
            case 'error':
                return 'destructive';
            case 'pending':
                return 'outline';
            default:
                return 'outline';
        }
    }
</script>

{#if error}
    <Alert variant="destructive">
        <AlertDescription>{error}</AlertDescription>
    </Alert>
{:else if loading}
    <div class="space-y-4">
        <Card>
            <CardHeader>
                <Skeleton class="h-6 w-48" />
            </CardHeader>
            <CardContent>
                <div class="grid grid-cols-2 gap-4">
                    {#each Array(6) as _, i (i)}
                        <div class="space-y-2">
                            <Skeleton class="h-4 w-20" />
                            <Skeleton class="h-4 w-32" />
                        </div>
                    {/each}
                </div>
            </CardContent>
        </Card>
        <Card>
            <CardHeader>
                <Skeleton class="h-5 w-32" />
            </CardHeader>
            <CardContent>
                <Skeleton class="h-32 w-full" />
            </CardContent>
        </Card>
    </div>
{:else if resource}
    <div class="space-y-6">
        <!-- Resource Information Card -->
        <Card>
            <CardHeader>
                <CardTitle class="flex items-center gap-2">
                    <FileText class="h-5 w-5" />
                    Resource: {resource.file_name}
                </CardTitle>
            </CardHeader>
            <CardContent>
                <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
                    <div class="flex items-center gap-2">
                        <Database class="text-muted-foreground h-4 w-4" />
                        <span class="font-medium">Type:</span>
                        <Badge variant="outline"
                            >{formatResourceType(resource.resource_type)}</Badge>
                    </div>
                    <div class="flex items-center gap-2">
                        <Hash class="text-muted-foreground h-4 w-4" />
                        <span class="font-medium">Size:</span>
                        <span>{formatFileSize(resource.byte_size)}</span>
                    </div>
                    <div class="flex items-center gap-2">
                        <FileText class="text-muted-foreground h-4 w-4" />
                        <span class="font-medium">Lines:</span>
                        <span>{resource.line_count?.toLocaleString() || 'N/A'}</span>
                    </div>
                    <div class="flex items-center gap-2">
                        <Hash class="text-muted-foreground h-4 w-4" />
                        <span class="font-medium">Checksum:</span>
                        <code class="bg-muted rounded px-1 py-0.5 text-xs"
                            >{resource.checksum}</code>
                    </div>
                    <div class="flex items-center gap-2">
                        <Link class="text-muted-foreground h-4 w-4" />
                        <span class="font-medium">ID:</span>
                        <code class="bg-muted rounded px-1 py-0.5 text-xs">{resource.id}</code>
                    </div>
                    <div class="flex items-center gap-2">
                        <Calendar class="text-muted-foreground h-4 w-4" />
                        <span class="font-medium">Updated:</span>
                        <span>{formatDate(resource.updated_at)}</span>
                    </div>
                </div>
            </CardContent>
        </Card>

        <!-- Linked Attacks Card -->
        <Card>
            <CardHeader>
                <CardTitle class="flex items-center gap-2">
                    <Link class="h-5 w-5" />
                    Linked Attacks
                </CardTitle>
            </CardHeader>
            <CardContent>
                {#if attacks && attacks.length > 0}
                    <div class="rounded-md border">
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>ID</TableHead>
                                    <TableHead>Name</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {#each attacks as attack (attack.id)}
                                    <TableRow>
                                        <TableCell class="font-mono text-sm">{attack.id}</TableCell>
                                        <TableCell>{attack.name}</TableCell>
                                    </TableRow>
                                {/each}
                            </TableBody>
                        </Table>
                    </div>
                {:else}
                    <div class="text-muted-foreground py-8 text-center">
                        <Link class="mx-auto mb-4 h-12 w-12 opacity-50" />
                        <p>No attacks linked to this resource.</p>
                    </div>
                {/if}
            </CardContent>
        </Card>
    </div>
{/if}
