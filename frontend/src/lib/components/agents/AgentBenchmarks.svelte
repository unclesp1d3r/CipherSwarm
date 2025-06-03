<script lang="ts">
	import Table from '../ui/table/table.svelte';
	import TableHeader from '../ui/table/table-header.svelte';
	import TableBody from '../ui/table/table-body.svelte';
	import TableRow from '../ui/table/table-row.svelte';
	import TableCell from '../ui/table/table-cell.svelte';
	import Button from '../ui/button/button.svelte';

	interface Benchmark {
		hash_type_id: string | number;
		hash_type_name: string;
		hash_type_description?: string;
		hash_speed: number;
		device: string;
		runtime?: number;
		created_at?: string;
	}

	export let benchmarks_by_hash_type: Record<string, Benchmark[]> = {};
	const hasBenchmarks = Object.keys(benchmarks_by_hash_type).length > 0;
</script>

<div class="mt-4">
	<h4 class="text-md mb-2 font-semibold">Benchmark Summary</h4>
	{#if !hasBenchmarks}
		<div class="italic text-gray-500">No benchmark results available for this agent.</div>
	{:else}
		<div class="overflow-x-auto">
			<Table>
				<TableHeader>
					<TableRow>
						<TableCell>Hash Mode</TableCell>
						<TableCell>Name</TableCell>
						<TableCell>Speed (h/s)</TableCell>
						<TableCell>Devices</TableCell>
					</TableRow>
				</TableHeader>
				<TableBody>
					{#each Object.entries(benchmarks_by_hash_type) as [hash_type_id, benches] (hash_type_id)}
						<TableRow>
							<TableCell>{benches[0]?.hash_type_id}</TableCell>
							<TableCell
								>{benches[0]?.hash_type_name}<br /><span
									class="text-xs text-gray-500"
									>{benches[0]?.hash_type_description}</span
								></TableCell
							>
							<TableCell
								>{benches
									.reduce((acc, b) => acc + b.hash_speed, 0)
									.toLocaleString()}</TableCell
							>
							<TableCell>
								<Button size="sm" variant="link"
									>View Devices {benches.length}</Button
								>
							</TableCell>
						</TableRow>
					{/each}
				</TableBody>
			</Table>
		</div>
	{/if}
</div>
