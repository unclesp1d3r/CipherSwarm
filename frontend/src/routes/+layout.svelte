<script lang="ts">
	import '../app.css';
	import SidebarProvider from '$lib/components/ui/sidebar/sidebar-provider.svelte';
	import Sidebar from '$lib/components/layout/Sidebar.svelte';
	import Header from '$lib/components/layout/Header.svelte';
	import Toast from '$lib/components/layout/Toast.svelte';
</script>

<div class="bg-background flex min-h-screen">
	<SidebarProvider>
		<Sidebar />
	</SidebarProvider>
	<div class="flex min-h-screen flex-1 flex-col">
		<Header />
		<main class="flex-1 p-4">
			<slot />
		</main>
		<Toast />
	</div>
</div>
