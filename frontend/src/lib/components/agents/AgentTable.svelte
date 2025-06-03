<script lang="ts">
	import Table from '../ui/table/table.svelte';
	import TableHeader from '../ui/table/table-header.svelte';
	import TableBody from '../ui/table/table-body.svelte';
	import TableRow from '../ui/table/table-row.svelte';
	import TableCell from '../ui/table/table-cell.svelte';
	import AgentRow from './AgentRow.svelte';

	interface Agent {
		id: number | string;
		host_name: string;
		operating_system: string;
		state: string;
		devices: string[];
		last_seen_at?: string;
	}

	export let agents: Agent[] = [];
</script>

<Table>
	<TableHeader>
		<TableRow>
			<TableCell>Host Name</TableCell>
			<TableCell>Operating System</TableCell>
			<TableCell>State</TableCell>
			<TableCell>Devices</TableCell>
			<TableCell>Last Seen</TableCell>
			<TableCell>Actions</TableCell>
		</TableRow>
	</TableHeader>
	<TableBody>
		{#if agents.length === 0}
			<TableRow>
				<TableCell colspan={6} class="text-center text-gray-500">No agents found.</TableCell
				>
			</TableRow>
		{:else}
			{#each agents as agent (agent.id)}
				<AgentRow {agent} />
			{/each}
		{/if}
	</TableBody>
</Table>
