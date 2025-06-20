<script lang="ts">
    interface Props {
        keyspace?: number | string;
        complexityScore?: number;
    }

    let { keyspace = 0, complexityScore = 1 }: Props = $props();

    function formatKeyspace(value: number | string): string {
        const num = typeof value === 'string' ? parseInt(value, 10) : value;
        if (isNaN(num)) return '0';
        return new Intl.NumberFormat().format(num);
    }
</script>

<div class="rounded-lg bg-gray-50 p-2 text-sm shadow dark:bg-gray-700">
    <div class="mb-1">
        <strong>Keyspace Estimate:</strong>
        {formatKeyspace(keyspace)}
    </div>
    <div>
        <strong>Complexity Score:</strong>
        {complexityScore}
    </div>
</div>
