<script lang="ts">
	import '../app.css';
	import SidebarProvider from '$lib/components/ui/sidebar/sidebar-provider.svelte';
	import Sidebar from '$lib/components/ui/sidebar/sidebar.svelte';
	import { default as Toaster } from '$lib/components/ui/sonner/sonner.svelte';
	import Menubar from '$lib/components/ui/menubar/menubar.svelte';
	import Avatar from '$lib/components/ui/avatar/avatar.svelte';
	// TODO: Import session/project/user stores when implemented
</script>

<div class="flex min-h-screen bg-background">
	<SidebarProvider>
		<Sidebar class="border-r border-border">
			<!-- TODO: Replace with real nav items and role-aware logic -->
			<div class="p-4 font-bold text-lg">CipherSwarm</div>
			<nav class="flex flex-col gap-2 p-2">
				<a href="/" class="hover:bg-accent rounded px-3 py-2">Dashboard</a>
				<a href="/campaigns" class="hover:bg-accent rounded px-3 py-2">Campaigns</a>
				<a href="/attacks" class="hover:bg-accent rounded px-3 py-2">Attacks</a>
				<a href="/agents" class="hover:bg-accent rounded px-3 py-2">Agents</a>
				<a href="/resources" class="hover:bg-accent rounded px-3 py-2">Resources</a>
				<a href="/users" class="hover:bg-accent rounded px-3 py-2">Users</a>
				<a href="/settings" class="hover:bg-accent rounded px-3 py-2">Settings</a>
			</nav>
		</Sidebar>
	</SidebarProvider>
	<div class="flex-1 flex flex-col min-h-screen">
		<header class="border-b border-border flex items-center justify-between px-6 h-16 bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
			<div class="flex items-center gap-4">
				<!-- Project selector placeholder -->
				<Menubar>
					<!-- TODO: Add project selection logic -->
					<span class="font-semibold">Project</span>
				</Menubar>
			</div>
			<div class="flex items-center gap-4">
				<!-- Status indicators placeholder -->
				<span class="text-xs text-muted-foreground">● Online</span>
				<!-- User avatar dropdown placeholder -->
				<Avatar />
			</div>
		</header>
		<main class="flex-1 p-6">
			<slot />
		</main>
	</div>
	<Toaster />
</div>
