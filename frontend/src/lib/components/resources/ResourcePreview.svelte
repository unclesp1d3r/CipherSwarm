<script lang="ts">
	import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/ui/card';
	import { Badge } from '$lib/components/ui/badge';
	import { Alert, AlertDescription } from '$lib/components/ui/alert';
	import { Skeleton } from '$lib/components/ui/skeleton';
	import { FileText, AlertTriangle } from '@lucide/svelte';

	interface Resource {
		id: string;
		file_name: string;
		resource_type: string;
	}

	export let resource: Resource | null = null;
	export let previewLines: string[] = [];
	export let previewError: string | null = null;
	export let maxPreviewLines = 50;
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
					<Skeleton class="h-4 w-full" />
				{/each}
			</div>
		</CardContent>
	</Card>
{:else if resource}
	<Card>
		<CardHeader>
			<CardTitle class="flex items-center gap-2">
				<FileText class="h-5 w-5" />
				Preview: {resource.file_name}
				<Badge variant={getResourceTypeVariant(resource.resource_type)} class="ml-2">
					{formatResourceType(resource.resource_type)}
				</Badge>
			</CardTitle>
		</CardHeader>
		<CardContent>
			{#if previewError}
				<Alert variant="destructive">
					<AlertTriangle class="h-4 w-4" />
					<AlertDescription>{previewError}</AlertDescription>
				</Alert>
			{:else if previewLines.length > 0}
				<div class="bg-muted/50 overflow-x-auto rounded-md border p-4">
					<pre
						class="max-h-64 overflow-y-auto whitespace-pre-wrap font-mono text-sm leading-tight">{#each previewLines as line, i (i)}{line}
						{/each}{#if previewLines.length === maxPreviewLines}... (truncated){/if}</pre>
				</div>
			{:else}
				<div class="text-muted-foreground py-8 text-center">
					<FileText class="mx-auto mb-4 h-12 w-12 opacity-50" />
					<p>No preview available for this resource.</p>
				</div>
			{/if}
		</CardContent>
	</Card>
{/if}
