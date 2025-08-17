<script lang="ts">
    import * as Table from '$lib/components/ui/table/index.js';
    export let benchmarksByHashType: Record<
        string,
        Array<{
            hash_type_id: string;
            hash_type_name: string;
            hash_type_description?: string;
            hash_speed: number;
            device: string;
            runtime: number;
            created_at: string;
        }>
    > = {};
    function humanizeSpeed(speed: number): string {
        if (speed >= 1e9) return (speed / 1e9).toFixed(2) + ' GH/s';
        if (speed >= 1e6) return (speed / 1e6).toFixed(2) + ' MH/s';
        if (speed >= 1e3) return (speed / 1e3).toFixed(2) + ' kH/s';
        return speed.toLocaleString() + ' H/s';
    }
    let expanded: Record<string, boolean> = {};
    function toggleDevices(hashTypeId: string) {
        expanded[hashTypeId] = !expanded[hashTypeId];
    }
    $: hasBenchmarks = Object.keys(benchmarksByHashType).length > 0;
</script>

<div class="mt-4">
    <h4 class="text-md mb-2 font-semibold">Benchmark Summary</h4>
    {#if !hasBenchmarks}
        <div class="text-gray-500 italic">No benchmark results available for this agent.</div>
    {:else}
        <div class="overflow-x-auto">
            <Table.Root class="min-w-full divide-y divide-gray-200 text-sm">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-4 py-2 text-left font-medium text-gray-700">Hash Mode</th>
                        <th class="px-4 py-2 text-left font-medium text-gray-700">Name</th>
                        <th class="px-4 py-2 text-left font-medium text-gray-700">Speed (h/s)</th>
                        <th class="px-4 py-2 text-left font-medium text-gray-700">Devices</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-100 bg-white">
                    {#each Object.entries(benchmarksByHashType) as [hashTypeId, benches] (hashTypeId)}
                        {#if benches.length > 0}
                            <tr class="hover:bg-gray-50">
                                <td class="px-4 py-2 font-mono">{benches[0].hash_type_id}</td>
                                <td class="px-4 py-2">
                                    <span class="font-semibold">{benches[0].hash_type_name}</span>
                                    {#if benches[0].hash_type_description}
                                        <br /><span class="text-xs text-gray-500"
                                            >{benches[0].hash_type_description}</span>
                                    {/if}
                                </td>
                                <td class="px-4 py-2"
                                    >{humanizeSpeed(
                                        benches.reduce((acc, b) => acc + b.hash_speed, 0)
                                    )}</td>
                                <td class="px-4 py-2">
                                    <button
                                        type="button"
                                        class="text-blue-600 hover:underline"
                                        on:click={() => toggleDevices(hashTypeId)}>
                                        View Devices ({benches.length})
                                    </button>
                                </td>
                            </tr>
                            {#if expanded[hashTypeId]}
                                <tr>
                                    <td colspan="4" class="bg-gray-50 px-4 py-2">
                                        <div class="grid grid-cols-1 gap-2 md:grid-cols-2">
                                            {#each benches as b (b.device + b.hash_type_id)}
                                                <div
                                                    class="flex flex-col rounded border bg-white p-2">
                                                    <div class="font-mono text-xs text-gray-600">
                                                        Device: {b.device}
                                                    </div>
                                                    <div class="text-xs text-gray-500">
                                                        Speed: {humanizeSpeed(b.hash_speed)}
                                                    </div>
                                                    <div class="text-xs text-gray-500">
                                                        Runtime: {b.runtime} ms
                                                    </div>
                                                    <div class="text-xs text-gray-400">
                                                        Benchmarked: {b.created_at}
                                                    </div>
                                                </div>
                                            {/each}
                                        </div>
                                    </td>
                                </tr>
                            {/if}
                        {/if}
                    {/each}
                </tbody>
            </Table.Root>
        </div>
    {/if}
</div>
