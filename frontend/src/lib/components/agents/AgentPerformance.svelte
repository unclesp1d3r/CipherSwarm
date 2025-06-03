<script lang="ts">
	interface DevicePerformance {
		device: string;
		// Add more fields as needed for chart rendering
	}
	export let series: DevicePerformance[] = [];
</script>

{#if series && series.length > 0}
	<div class="agent-performance-charts">
		{#each series as device (device.device)}
			<div class="device-chart mb-6">
				<h3 class="mb-2 text-lg font-semibold">{device.device}</h3>
				<div class="flex h-60 items-center justify-center rounded bg-gray-100">
					[Chart Placeholder]
				</div>
			</div>
		{/each}
	</div>
{:else}
	<div class="italic text-gray-500">No device performance data available for this agent.</div>
{/if}
