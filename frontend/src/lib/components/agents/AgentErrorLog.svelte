<script lang="ts">
	export let errors: Array<{
		created_at: string;
		severity: string;
		message: string;
		task_id?: number;
		error_code?: string;
	}> = [];
	function formatTime(ts: string) {
		return ts ? new Date(ts).toLocaleString() : '';
	}
</script>

{#if errors && errors.length > 0}
	<div class="overflow-x-auto">
		<table class="min-w-full divide-y divide-gray-200">
			<thead class="bg-gray-50">
				<tr>
					<th
						class="px-4 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
						>Time</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
						>Severity</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
						>Message</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
						>Task</th
					>
					<th
						class="px-4 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
						>Error Code</th
					>
				</tr>
			</thead>
			<tbody class="divide-y divide-gray-200 bg-white">
				{#each errors as error (error.created_at + error.message)}
					<tr>
						<td class="whitespace-nowrap px-4 py-2 text-xs text-gray-500"
							>{formatTime(error.created_at)}</td
						>
						<td class="whitespace-nowrap px-4 py-2">
							{#if error.severity === 'minor'}
								<span
									class="inline-block rounded bg-yellow-100 px-2 py-1 text-xs font-semibold text-yellow-800"
									>Minor</span
								>
							{:else if error.severity === 'critical'}
								<span
									class="inline-block rounded bg-red-100 px-2 py-1 text-xs font-semibold text-red-800"
									>Critical</span
								>
							{:else}
								<span
									class="inline-block rounded bg-gray-100 px-2 py-1 text-xs font-semibold text-gray-800"
									>Info</span
								>
							{/if}
						</td>
						<td class="px-4 py-2 text-xs text-gray-900">{error.message}</td>
						<td class="px-4 py-2 text-xs text-gray-500"
							>{error.task_id ? `#${error.task_id}` : '-'}</td
						>
						<td class="px-4 py-2 text-xs text-gray-500">{error.error_code || '-'}</td>
					</tr>
				{/each}
			</tbody>
		</table>
	</div>
{:else}
	<div class="py-4 text-sm italic text-gray-400">No errors reported for this agent.</div>
{/if}
