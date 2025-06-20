<script lang="ts">
    import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/ui/card';

    interface Props {
        attackName: string;
        totalHashes?: number;
        hashesDone?: number;
        agentCount?: number;
        hashesPerSec?: number;
        progress?: number;
        eta?: number;
    }

    let {
        attackName,
        totalHashes,
        hashesDone = 0,
        agentCount = 0,
        hashesPerSec,
        progress,
        eta
    }: Props = $props();

    function formatEta(seconds: number): string {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = Math.floor(seconds % 60);
        return `${hours}h ${minutes}m ${secs}s`;
    }

    function formatNumber(num: number): string {
        return new Intl.NumberFormat().format(num);
    }
</script>

<Card class="bg-white dark:bg-gray-800">
    <CardHeader class="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle class="text-sm font-semibold text-gray-700 dark:text-gray-200">
            Performance Summary
        </CardTitle>
        <span class="text-xs text-gray-400">Attack: {attackName}</span>
    </CardHeader>
    <CardContent>
        <div class="grid grid-cols-2 gap-2 text-sm">
            <div class="flex justify-between">
                <span class="font-medium">Total Hashes:</span>
                <span>{totalHashes ? formatNumber(totalHashes) : 'N/A'}</span>
            </div>
            <div class="flex justify-between">
                <span class="font-medium">Hashes Done:</span>
                <span>{formatNumber(hashesDone)}</span>
            </div>
            <div class="flex justify-between">
                <span class="font-medium">Agents:</span>
                <span>{agentCount}</span>
            </div>
            <div class="flex justify-between">
                <span class="font-medium">Speed:</span>
                <span>{hashesPerSec ? `${Math.round(hashesPerSec)} H/s` : 'N/A'}</span>
            </div>
            <div class="flex justify-between">
                <span class="font-medium">Progress:</span>
                <span>{progress !== undefined ? `${progress.toFixed(1)}%` : 'N/A'}</span>
            </div>
            <div class="flex justify-between">
                <span class="font-medium">ETA:</span>
                <span>{eta !== undefined ? formatEta(eta) : 'N/A'}</span>
            </div>
        </div>
    </CardContent>
</Card>
