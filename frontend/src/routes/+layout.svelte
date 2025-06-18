<script lang="ts">
	import '../app.css';
	import * as Sidebar from '$lib/components/ui/sidebar/index.js';
	import Toast from '$lib/components/layout/Toast.svelte';
	import AppSidebar from '$lib/components/layout/AppSidebar.svelte';
	import { ModeWatcher } from 'mode-watcher';
	import { page } from '$app/stores';

	let { children } = $props();

	// Show sidebar only for protected routes (not login/logout)
	const showSidebar = $derived(
		!$page.route.id?.includes('login') && !$page.route.id?.includes('logout')
	);
</script>

<svelte:head>
	<title>CipherSwarm</title>
</svelte:head>

{#if showSidebar}
	<Sidebar.Provider>
		<AppSidebar />
		<ModeWatcher />
		{@render children?.()}
	</Sidebar.Provider>
{:else}
	<ModeWatcher />
	{@render children?.()}
{/if}
<Toast />
