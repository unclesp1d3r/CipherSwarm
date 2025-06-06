<script lang="ts">
	interface Props {
		mode: string;
		keyspace?: number | string;
		complexity?: string;
		complexityScore?: number;
	}

	let { mode, keyspace, complexity, complexityScore }: Props = $props();

	function formatKeyspace(value: number | string | undefined): string {
		if (value === undefined) return 'N/A';
		const num = typeof value === 'string' ? parseInt(value, 10) : value;
		if (isNaN(num)) return 'N/A';
		return new Intl.NumberFormat().format(num);
	}
</script>

<div
	class="rounded border border-green-200 bg-green-50 p-4 dark:border-green-800 dark:bg-green-900/20"
>
	<h4 class="font-bold text-green-700 dark:text-green-300">Attack Validated</h4>
	<div class="mt-2 space-y-1">
		<p><strong>Mode:</strong> {mode}</p>
		<p><strong>Keyspace:</strong> {formatKeyspace(keyspace)}</p>
		{#if complexity}
			<p><strong>Complexity:</strong> {complexity}</p>
		{/if}
		{#if complexityScore !== undefined}
			<p><strong>Complexity Score:</strong> {complexityScore}</p>
		{/if}
	</div>
</div>
