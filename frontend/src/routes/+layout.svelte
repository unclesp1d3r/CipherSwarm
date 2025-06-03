<script lang="ts">
	import '../app.css';
	import * as Sidebar from '$lib/components/ui/sidebar/index.js';
	import Toast from '$lib/components/layout/Toast.svelte';
	import AppSidebar from '$lib/components/layout/AppSidebar.svelte';
	import { ModeWatcher } from 'mode-watcher';

	let { children } = $props();
</script>

<Sidebar.Provider>
	<AppSidebar />
	<ModeWatcher />
	{@render children?.()}
</Sidebar.Provider>
<Toast />
