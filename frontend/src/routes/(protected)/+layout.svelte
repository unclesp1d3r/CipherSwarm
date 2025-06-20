<script lang="ts">
    import { authStore } from '$lib/stores/auth.svelte';
    import { onMount } from 'svelte';

    let { data, children } = $props();

    // Initialize auth store with SSR data
    onMount(() => {
        if (data.user) {
            authStore.setUser(data.user);
        }
    });
</script>

{@render children()}
