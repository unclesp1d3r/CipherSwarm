<script lang="ts">
	import AgentList from '$lib/components/agents/AgentList.svelte';
	import type { PageData } from './$types';

	export let data: PageData;
</script>

<AgentList agents={data.agents} />
