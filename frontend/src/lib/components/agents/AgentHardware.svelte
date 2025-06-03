<script lang="ts">
	import Button from '../ui/button/button.svelte';

	interface Agent {
		id: number | string;
		devices: string[];
		operating_system: string;
	}

	interface AdvancedConfiguration {
		agent_update_interval?: number;
		use_native_hashcat?: boolean;
		backend_device?: string;
		opencl_devices?: string;
		enable_additional_hash_types?: boolean;
	}

	export let agent: Agent;
	export let advanced_configuration: AdvancedConfiguration;
</script>

<div class="p-4">
	<h4 class="text-md mb-2 font-semibold">Hardware Details</h4>
	<form class="mb-4">
		<label class="mb-2 block text-xs font-medium text-gray-500" for="backend-devices-list"
			>Backend Devices</label
		>
		<div class="flex flex-col gap-2" id="backend-devices-list">
			{#each agent.devices as device, idx (idx)}
				<label class="flex items-center gap-2" for={`device-checkbox-${idx}`}>
					<input
						id={`device-checkbox-${idx}`}
						type="checkbox"
						name="enabled_indices"
						value={idx}
						class="form-checkbox h-4 w-4 rounded border-gray-300 text-indigo-600"
					/>
					<span>{device}</span>
				</label>
			{/each}
		</div>
		<Button type="submit" size="sm" class="mt-2">Update Devices</Button>
	</form>
	<form class="mb-6 grid grid-cols-2 gap-x-4 gap-y-2">
		<input type="hidden" name="agent_id" value={agent.id} />
		<div>
			<label class="text-xs text-gray-500" for="update-interval">Update Interval (s)</label>
			<input
				id="update-interval"
				type="number"
				name="agent_update_interval"
				value={advanced_configuration.agent_update_interval || 30}
				min="1"
				required
				class="w-full"
			/>
		</div>
		<div>
			<label class="text-xs text-gray-500" for="native-hashcat">Native Hashcat</label>
			<select id="native-hashcat" name="use_native_hashcat" class="w-full">
				<option value="true" selected={!!advanced_configuration.use_native_hashcat}
					>Yes</option
				>
				<option value="false" selected={!advanced_configuration.use_native_hashcat}
					>No</option
				>
			</select>
		</div>
		<div>
			<label class="text-xs text-gray-500" for="backend-device">Backend Device</label>
			<input
				id="backend-device"
				type="text"
				name="backend"
				value={advanced_configuration.backend_device || ''}
				class="w-full"
			/>
		</div>
		<div>
			<label class="text-xs text-gray-500" for="opencl-devices">OpenCL Devices</label>
			<input
				id="opencl-devices"
				type="text"
				name="opencl_devices"
				value={advanced_configuration.opencl_devices || ''}
				class="w-full"
			/>
		</div>
		<div>
			<label class="text-xs text-gray-500" for="additional-hash-types"
				>Additional Hash Types</label
			>
			<select id="additional-hash-types" name="enable_additional_hash_types" class="w-full">
				<option
					value="true"
					selected={!!advanced_configuration.enable_additional_hash_types}>Enabled</option
				>
				<option
					value="false"
					selected={!advanced_configuration.enable_additional_hash_types}>Disabled</option
				>
			</select>
		</div>
		<div class="col-span-2 mt-2">
			<Button type="submit" class="w-full">Save Configuration</Button>
		</div>
	</form>
	<div class="mb-4">
		<label class="mb-2 block text-xs font-medium text-gray-500" for="platform-support"
			>Platform Support</label
		>
		<ul class="flex flex-wrap gap-2">
			{#if advanced_configuration.opencl_devices}
				<li class="rounded bg-blue-100 px-2 py-1 text-xs text-blue-800">OpenCL</li>
			{/if}
			{#if advanced_configuration.backend_device}
				<li class="rounded bg-green-100 px-2 py-1 text-xs text-green-800">Backend</li>
			{/if}
			<li class="rounded bg-gray-100 px-2 py-1 text-xs text-gray-800">
				{agent.operating_system}
			</li>
		</ul>
	</div>
</div>
