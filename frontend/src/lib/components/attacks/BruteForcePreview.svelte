<script lang="ts">
    interface Props {
        customCharset: string;
        mask: string;
    }

    let { customCharset, mask }: Props = $props();
</script>

<div class="mb-4">
    <label
        for="charset-preview"
        class="mb-2 block text-sm font-medium text-gray-900 dark:text-white"
    >
        Charset Preview (?1)
    </label>
    <input
        id="charset-preview"
        type="text"
        readonly
        class="w-full rounded-lg border border-gray-300 bg-gray-100 px-3 py-2 text-sm text-gray-900 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
        value={customCharset}
    />
</div>
<div class="mb-4">
    <label
        for="generated-mask"
        class="mb-2 block text-sm font-medium text-gray-900 dark:text-white"
    >
        Generated Mask
    </label>
    <input
        id="generated-mask"
        type="text"
        readonly
        class="w-full rounded-lg border border-gray-300 bg-gray-100 px-3 py-2 text-sm text-gray-900 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
        value={mask}
    />
</div>
