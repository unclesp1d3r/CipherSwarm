<script context="module" lang="ts">
	// Define a type for agent
	// Inline Agent interface for type safety
	export interface Agent {
		id: number;
		host_name: string;
		devices: string[];
		operating_system: string;
		advanced_configuration?: {
			backend_device?: string;
			agent_update_interval?: number;
			use_native_hashcat?: boolean;
			opencl_devices?: string;
			enable_additional_hash_types?: boolean;
			hwmon_temp_abort?: number;
		};
	}
	export interface AgentError {
		created_at: string;
		severity: string;
		message: string;
		task_id?: number;
		error_code?: string;
	}
	export interface AgentBenchmark {
		hash_type_id: string;
		hash_type_name: string;
		hash_type_description?: string;
		hash_speed: number;
		device: string;
		runtime: number;
		created_at: string;
	}
	export interface AgentDetails extends Agent {
		custom_label?: string;
		state: string;
		temperature: number | null;
		utilization: number | null;
		current_attempts_sec: number;
		avg_attempts_sec: number;
		current_job: string;
		benchmarks_by_hash_type?: Record<string, AgentBenchmark[]>;
		performance_series?: Array<{
			device: string;
			data: Array<{ timestamp: string; speed: number }>;
		}>;
		errors?: AgentError[];
		last_seen_ip?: string;
		client_signature?: string;
		token?: string;
	}
</script>

<script lang="ts">
	import * as Form from '$lib/components/ui/form/index.js';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import { superForm, defaults } from 'sveltekit-superforms/client';
	import Switch from '$lib/components/ui/switch/switch.svelte';
	import { isAdmin } from '$lib/stores/session';
	import { z } from 'zod';
	import { onMount, createEventDispatcher } from 'svelte';
	import AgentBenchmarks from './AgentBenchmarks.svelte';
	import AgentHardware from './AgentHardware.svelte';
	import AgentPerformance from './AgentPerformance.svelte';
	import AgentErrorLog from './AgentErrorLog.svelte';
	import { Tabs, TabsList, TabsTrigger, TabsContent } from '$lib/components/ui/tabs';
	import Button from '$lib/components/ui/button/button.svelte';
	import { Input } from '$lib/components/ui/input';
	export let agent: AgentDetails | null = null;

	let activeTab = 'settings';

	const schema = z.object({
		label: z.string().optional(),
		enabled: z.boolean().optional(),
		updateInterval: z.number().min(1, 'Must be at least 1 second').max(3600),
		useNativeHashcat: z.boolean().optional(),
		enableAdditionalHashTypes: z.boolean().optional(),
		gpuEnabled: z.boolean().optional(),
		cpuEnabled: z.boolean().optional()
	});
	const initialData = {
		label: agent?.custom_label ?? '',
		enabled: true,
		updateInterval: 30,
		useNativeHashcat: false,
		enableAdditionalHashTypes: false,
		gpuEnabled: true,
		cpuEnabled: true
	};
	const form = superForm(defaults(initialData, zodClient(schema)), {
		SPA: true,
		validators: zodClient(schema),
		id: 'agent-details',
		dataType: 'json'
	});

	const dispatch = createEventDispatcher();
	function handleClose() {
		dispatch('close');
	}

	const { form: formData, enhance } = form;
</script>

<div class="w-full max-w-lg">
	<h2 class="mb-4 text-xl font-bold">Agent Details</h2>
	{#if !agent}
		<div class="text-muted-foreground py-8 text-center">No agent selected.</div>
	{:else}
		<Tabs bind:value={activeTab}>
			<TabsList>
				<TabsTrigger value="settings">Settings</TabsTrigger>
				<TabsTrigger value="hardware">Hardware</TabsTrigger>
				<TabsTrigger value="performance">Performance</TabsTrigger>
				<TabsTrigger value="log">Log</TabsTrigger>
				<TabsTrigger value="capabilities">Capabilities</TabsTrigger>
			</TabsList>
			<TabsContent value="settings">
				<form dataType="json" class="space-y-4" use:enhance>
					<Form.Field {form} name="label">
						<Form.Control>
							{#snippet children({ props })}
								<Form.Label>Agent Label</Form.Label>
								<Input
									{...props}
									bind:value={$formData.label}
									aria-label="Agent Label"
								/>
							{/snippet}
						</Form.Control>
						<Form.Description>Set a custom label for this agent</Form.Description>
						<Form.FieldErrors />
					</Form.Field>
					<Form.Field {form} name="enabled">
						<Form.Control>
							{#snippet children({ props })}
								<Form.Label>Enabled</Form.Label>
								<Switch {...props} bind:checked={$formData.enabled} />
							{/snippet}
						</Form.Control>
						<Form.Description>Enable or disable this agent</Form.Description>
						<Form.FieldErrors />
					</Form.Field>
					<Form.Field {form} name="updateInterval">
						<Form.Control>
							{#snippet children({ props })}
								<Form.Label>Update Interval</Form.Label>
								<Input
									{...props}
									type="number"
									min="1"
									max="3600"
									bind:value={$formData.updateInterval}
									aria-label="Update Interval"
								/>
							{/snippet}
						</Form.Control>
						<Form.Description
							>How often the agent should update (in seconds)</Form.Description
						>
						<Form.FieldErrors />
					</Form.Field>
					<Form.Field {form} name="useNativeHashcat">
						<Form.Control>
							{#snippet children({ props })}
								<Form.Label>Use Native Hashcat</Form.Label>
								<Switch {...props} bind:checked={$formData.useNativeHashcat} />
							{/snippet}
						</Form.Control>
						<Form.Description>Enable native hashcat for this agent</Form.Description>
						<Form.FieldErrors />
					</Form.Field>
					<Form.Field {form} name="enableAdditionalHashTypes">
						<Form.Control>
							{#snippet children({ props })}
								<Form.Label>Enable Additional Hash Types</Form.Label>
								<Switch
									{...props}
									bind:checked={$formData.enableAdditionalHashTypes}
								/>
							{/snippet}
						</Form.Control>
						<Form.Description>Enable all hash types for benchmarking</Form.Description>
						<Form.FieldErrors />
					</Form.Field>
					<!-- Project assignment and system info would go here -->
					<Form.Button class="w-full">Save</Form.Button>
				</form>
				<div class="mt-4">
					<div class="text-muted-foreground text-xs">System Info:</div>
					<div class="text-xs">OS: {agent.operating_system}</div>
					<div class="text-xs">Last seen IP: {agent.last_seen_ip ?? '—'}</div>
					<div class="text-xs">Client signature: {agent.client_signature ?? '—'}</div>
					<div class="text-xs">Agent token: {agent.token ?? '—'}</div>
				</div>
			</TabsContent>
			<TabsContent value="hardware">
				<h3 class="mb-2 text-lg font-semibold">Hardware Details</h3>
				<AgentHardware {agent} isAdmin={$isAdmin} />
			</TabsContent>
			<TabsContent value="performance">
				<h3 class="mb-2 text-lg font-semibold">Performance</h3>
				<AgentPerformance series={agent.performance_series ?? []} />
			</TabsContent>
			<TabsContent value="log">
				<h3 class="mb-2 text-lg font-semibold">Error Log</h3>
				<AgentErrorLog errors={agent.errors ?? []} />
			</TabsContent>
			<TabsContent value="capabilities">
				<h3 class="mb-2 text-lg font-semibold">Benchmark Summary</h3>
				<AgentBenchmarks benchmarksByHashType={agent.benchmarks_by_hash_type ?? {}} />
			</TabsContent>
		</Tabs>
	{/if}
	<div class="mt-6 flex justify-end">
		<Button variant="secondary" data-testid="modal-close" onclick={handleClose}>Close</Button>
	</div>
</div>
