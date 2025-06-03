<script lang="ts">
	import Table from '../ui/table/table.svelte';
	import TableHeader from '../ui/table/table-header.svelte';
	import TableBody from '../ui/table/table-body.svelte';
	import TableRow from '../ui/table/table-row.svelte';
	import TableCell from '../ui/table/table-cell.svelte';
	import Badge from '../ui/badge/badge.svelte';

	interface AgentError {
		created_at: string;
		severity: string;
		message: string;
		task_id?: string | number;
		error_code?: string | number;
	}

	export let errors: AgentError[] = [];
</script>

{#if errors && errors.length > 0}
	<div class="overflow-x-auto">
		<Table>
			<TableHeader>
				<TableRow>
					<TableCell>Time</TableCell>
					<TableCell>Severity</TableCell>
					<TableCell>Message</TableCell>
					<TableCell>Task</TableCell>
					<TableCell>Error Code</TableCell>
				</TableRow>
			</TableHeader>
			<TableBody>
				{#each errors as error (error.created_at + error.message)}
					<TableRow>
						<TableCell>{error.created_at}</TableCell>
						<TableCell>
							{#if error.severity === 'minor'}
								<Badge class="bg-yellow-100 text-yellow-800">Minor</Badge>
							{:else if error.severity === 'critical'}
								<Badge class="bg-red-100 text-red-800">Critical</Badge>
							{:else}
								<Badge class="bg-gray-100 text-gray-800">Info</Badge>
							{/if}
						</TableCell>
						<TableCell>{error.message}</TableCell>
						<TableCell>{error.task_id ? `#${error.task_id}` : '-'}</TableCell>
						<TableCell>{error.error_code || '-'}</TableCell>
					</TableRow>
				{/each}
			</TableBody>
		</Table>
	</div>
{:else}
	<div class="py-4 text-sm italic text-gray-400">No errors reported for this agent.</div>
{/if}
