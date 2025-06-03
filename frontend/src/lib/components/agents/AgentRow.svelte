<script lang="ts">
	import TableRow from '../ui/table/table-row.svelte';
	import TableCell from '../ui/table/table-cell.svelte';
	import Badge from '../ui/badge/badge.svelte';
	import Button from '../ui/button/button.svelte';

	interface Agent {
		id: number | string;
		host_name: string;
		operating_system: string;
		state: string;
		devices: string[];
		last_seen_at?: string;
	}

	export let agent: Agent;
	const stateColor = {
		active: 'bg-green-100 text-green-800',
		pending: 'bg-yellow-100 text-yellow-800',
		stopped: 'bg-gray-100 text-gray-800',
		error: 'bg-red-100 text-red-800'
	};
</script>

<TableRow>
	<TableCell>{agent.host_name}</TableCell>
	<TableCell>{agent.operating_system}</TableCell>
	<TableCell>
		<Badge
			class={stateColor[agent.state as keyof typeof stateColor] ||
				'bg-gray-100 text-gray-800'}>{agent.state}</Badge
		>
	</TableCell>
	<TableCell>{agent.devices?.join(', ')}</TableCell>
	<TableCell>{agent.last_seen_at ? agent.last_seen_at : 'Never'}</TableCell>
	<TableCell>
		<div class="flex gap-2">
			<Button size="sm" variant="outline">Details</Button>
			{#if agent.state === 'active'}
				<Button size="sm" variant="destructive">Shutdown</Button>
			{/if}
		</div>
	</TableCell>
</TableRow>
