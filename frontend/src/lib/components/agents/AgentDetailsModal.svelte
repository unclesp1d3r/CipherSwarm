<script context="module" lang="ts">
	// Define a type for agent
	export interface AgentDetails {
		id: number;
		host_name: string;
		custom_label?: string;
		operating_system: string;
		state: string;
		temperature: number | null;
		utilization: number | null;
		current_attempts_sec: number;
		avg_attempts_sec: number;
		current_job: string;
	}
</script>

<script lang="ts">
	import * as Form from '$lib/components/ui/form/index.js';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import { superForm } from 'sveltekit-superforms';
	import Switch from '$lib/components/ui/switch/switch.svelte';
	import * as Dialog from '$lib/components/ui/dialog/index.js';
	import { isAdmin } from '$lib/stores/session';
	export let agent: AgentDetails | null;
	export let form; // SuperValidated passed from parent
	/**
	 * Controls whether the dialog is open. Defaults to true for testability and modal usage.
	 */
	export let open: boolean = true;

	// The schema should be defined and used in the parent/page, not here
	const schema = undefined; // placeholder, not used here

	function handleClose() {
		// @ts-expect-error Svelte 5 event dispatch is not typed yet
		this.dispatchEvent(new CustomEvent('close'));
	}
</script>

<Dialog.Root {open}>
	<Dialog.Content class="w-full max-w-lg">
		<Dialog.Header>
			<Dialog.Title>Agent Details</Dialog.Title>
		</Dialog.Header>
		{#if !agent}
			<div class="text-muted-foreground py-8 text-center">No agent selected.</div>
		{:else}
			<div class="space-y-4">
				<div>
					<div class="text-lg font-semibold">{agent.custom_label ?? agent.host_name}</div>
					<div class="text-muted-foreground text-xs">{agent.operating_system}</div>
					<div class="mt-2 flex flex-wrap gap-2 text-sm">
						<span class="badge">Status: {agent.state}</span>
						{#if agent.temperature !== null}
							<span class="badge">Temp: {agent.temperature}°C</span>
						{/if}
						{#if agent.utilization !== null}
							<span class="badge">Util: {Math.round(agent.utilization * 100)}%</span>
						{/if}
					</div>
				</div>
				<div class="bg-muted rounded p-2 text-xs">
					<div>
						<span class="font-medium">Current Job:</span>
						<span class="font-mono">{agent.current_job}</span>
					</div>
					<div>
						<span class="font-medium">Current Attempts/sec:</span>
						{agent.current_attempts_sec?.toLocaleString() ?? '—'}
					</div>
					<div>
						<span class="font-medium">Average Attempts/sec:</span>
						{agent.avg_attempts_sec?.toLocaleString() ?? '—'}
					</div>
				</div>
				{#if $isAdmin && form && typeof form.subscribe === 'function'}
					<form dataType="json" class="mt-6 space-y-4">
						<Form.Field {form} name="gpuEnabled">
							<Form.Control>
								<Form.Label>GPU</Form.Label>
								<Switch bind:checked={$form.gpuEnabled} id="gpuEnabled" />
							</Form.Control>
							<Form.Description>Enable GPU for this agent</Form.Description>
							<Form.FieldErrors />
						</Form.Field>
						<Form.Field {form} name="cpuEnabled">
							<Form.Control>
								<Form.Label>CPU</Form.Label>
								<Switch bind:checked={$form.cpuEnabled} id="cpuEnabled" />
							</Form.Control>
							<Form.Description>Enable CPU for this agent</Form.Description>
							<Form.FieldErrors />
						</Form.Field>
						<Form.Field {form} name="updateInterval">
							<Form.Control>
								<Form.Label>Update Interval (sec)</Form.Label>
								<input
									type="number"
									min="1"
									max="3600"
									class="input input-bordered w-full"
									bind:value={$form.updateInterval}
									id="updateInterval"
								/>
							</Form.Control>
							<Form.Description
								>How often the agent should update (in seconds)</Form.Description
							>
							<Form.FieldErrors />
						</Form.Field>
						<Form.Button class="w-full">Save</Form.Button>
					</form>
				{/if}
			</div>
		{/if}
		<Dialog.Footer>
			<Dialog.Close>
				<button type="button" class="btn btn-secondary" on:click={handleClose}>Close</button
				>
			</Dialog.Close>
		</Dialog.Footer>
	</Dialog.Content>
</Dialog.Root>
