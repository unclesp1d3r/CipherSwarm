<script module lang="ts">
    export interface Agent {
        id: number;
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
</script>

<script lang="ts">
    import { Input } from '$lib/components/ui/input';
    import { Label } from '$lib/components/ui/label';
    import { Checkbox } from '$lib/components/ui/checkbox';
    import { Switch } from '$lib/components/ui/switch';
    import { Button } from '$lib/components/ui/button';
    const { agent = { id: 0, devices: [], operating_system: '' }, isAdmin = false } = $props();
    // Svelte 5 runes for local state
    let advanced = $state(
        agent.advanced_configuration
            ? { ...agent.advanced_configuration }
            : {
                  backend_device: '',
                  agent_update_interval: 30,
                  use_native_hashcat: false,
                  opencl_devices: '',
                  enable_additional_hash_types: false,
                  hwmon_temp_abort: undefined
              }
    );
</script>

<div class="p-4">
    {#if isAdmin}
        <div class="mb-6">
            <Label for="backend-devices-list">Backend Devices</Label>
            <div class="flex flex-col gap-2" id="backend-devices-list">
                {#each agent.devices as device, idx (device)}
                    <label class="flex items-center gap-2" for={`device-checkbox-${idx}`}>
                        <Checkbox
                            id={`device-checkbox-${idx}`}
                            value={String(idx)}
                            checked={advanced.backend_device?.split(',').includes(String(idx))}
                            onchange={() => {
                                const indices =
                                    advanced.backend_device?.split(',').filter(Boolean) || [];
                                if (indices.includes(String(idx))) {
                                    advanced.backend_device = indices
                                        .filter((i: string) => i !== String(idx))
                                        .join(',');
                                } else {
                                    advanced.backend_device = [...indices, String(idx)].join(',');
                                }
                            }}
                        />
                        <span>{device}</span>
                    </label>
                {/each}
            </div>
            <Button variant="secondary" class="mt-2">Update Devices</Button>
        </div>
        <div class="mb-6 grid grid-cols-2 gap-x-4 gap-y-2">
            <div>
                <label class="text-xs text-gray-500" for="update-interval"
                    >Update Interval (s)</label
                >
                <Input
                    id="update-interval"
                    type="number"
                    min="1"
                    max="3600"
                    bind:value={advanced.agent_update_interval}
                />
            </div>
            <div>
                <label class="text-xs text-gray-500" for="native-hashcat">Native Hashcat</label>
                <Switch bind:checked={advanced.use_native_hashcat} />
            </div>
            <div>
                <label class="text-xs text-gray-500" for="backend-device">Backend Device</label>
                <Input id="backend-device" type="text" bind:value={advanced.backend_device} />
            </div>
            <div>
                <label class="text-xs text-gray-500" for="opencl-devices">OpenCL Devices</label>
                <Input id="opencl-devices" type="text" bind:value={advanced.opencl_devices} />
            </div>
            <div>
                <label class="text-xs text-gray-500" for="additional-hash-types"
                    >Additional Hash Types</label
                >
                <Switch bind:checked={advanced.enable_additional_hash_types} />
            </div>
            {#if advanced.hwmon_temp_abort !== undefined}
                <div>
                    <label class="text-xs text-gray-500" for="temp-abort">Temp Abort (°C)</label>
                    <Input
                        id="temp-abort"
                        type="number"
                        min="0"
                        bind:value={advanced.hwmon_temp_abort}
                    />
                </div>
            {/if}
            <div class="col-span-2 mt-2">
                <Button
                    variant="secondary"
                    class="w-full"
                    onclick={() => (agent.advanced_configuration = { ...advanced })}
                    >Save Configuration</Button
                >
            </div>
        </div>
    {/if}
    <div class="mb-4">
        <Label for="platform-support-list">Platform Support</Label>
        <ul class="flex flex-wrap gap-2" id="platform-support-list">
            {#if agent.advanced_configuration?.opencl_devices}
                <li class="rounded bg-blue-100 px-2 py-1 text-xs text-blue-800">OpenCL</li>
            {/if}
            {#if agent.advanced_configuration?.backend_device}
                <li class="rounded bg-green-100 px-2 py-1 text-xs text-green-800">Backend</li>
            {/if}
            <li class="rounded bg-gray-100 px-2 py-1 text-xs text-gray-800">
                {agent.operating_system}
            </li>
        </ul>
    </div>
</div>
