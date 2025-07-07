<script lang="ts">
    import { authStore } from '$lib/stores/auth.svelte';
    import { projectsStore } from '$lib/stores/projects.svelte';
    import { onMount } from 'svelte';

    let { data, children } = $props();

    // Initialize auth store with SSR data
    onMount(() => {
        if (data.user) {
            authStore.setUser(data.user);
        }

        // Initialize projects store with SSR data
        if (data.projects) {
            projectsStore.hydrateProjectContext(
                data.projects.activeProject,
                data.projects.availableProjects,
                data.projects.contextUser
            );
        }
    });
</script>

{@render children()}
