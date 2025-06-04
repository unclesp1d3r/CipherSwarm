<script lang="ts">
	import AgentDetailsModal, { type AgentDetails } from './AgentDetailsModal.svelte';
	import { superForm } from 'sveltekit-superforms';
	import { z } from 'zod';
	import { zodClient } from 'sveltekit-superforms/adapters';

	export let agent: AgentDetails | null = null;
	export let open = true;

	const schema = z.object({
		gpuEnabled: z.boolean(),
		cpuEnabled: z.boolean(),
		updateInterval: z.number().min(1, 'Must be at least 1 second').max(3600)
	});

	const form = superForm(
		{
			gpuEnabled: true,
			cpuEnabled: true,
			updateInterval: 30
		},
		{
			id: 'mock',
			SPA: true,
			validators: zodClient(schema),
			dataType: 'json'
		}
	).form;
</script>

<AgentDetailsModal {agent} {form} {open} />
