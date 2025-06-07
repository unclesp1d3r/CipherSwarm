<script lang="ts">
	import UserProfile from '$lib/components/users/UserProfile.svelte';
	import ProjectContext from '$lib/components/users/ProjectContext.svelte';
	import { Separator } from '$lib/components/ui/separator';
	import type { User } from '$lib/types/user';

	// Mock data for now - in production this would come from stores/API
	const mockUser: User = {
		id: '1',
		email: 'user@example.com',
		name: 'Current User',
		is_active: true,
		is_superuser: false,
		is_verified: true,
		created_at: '2023-01-01T00:00:00Z',
		updated_at: '2023-01-02T00:00:00Z',
		role: 'user'
	};

	const mockActiveProject = {
		id: 1,
		name: 'Project Alpha'
	};

	const mockAvailableProjects = [
		{ id: 1, name: 'Project Alpha', private: false },
		{ id: 2, name: 'Project Beta', private: true },
		{ id: 3, name: 'Project Gamma', private: false }
	];

	function handlePasswordChanged() {
		console.log('Password changed successfully');
	}

	function handleProjectSwitched() {
		console.log('Project switched successfully');
	}
</script>

<svelte:head>
	<title>Settings - CipherSwarm</title>
</svelte:head>

<div class="container mx-auto py-6">
	<div class="mb-6">
		<h1 class="text-3xl font-bold">Settings</h1>
		<p class="text-muted-foreground">Manage your account settings and preferences.</p>
	</div>

	<div class="space-y-8">
		<!-- Project Context Section -->
		<div>
			<h2 class="mb-4 text-xl font-semibold">Project Context</h2>
			<ProjectContext
				user={mockUser}
				activeProject={mockActiveProject}
				availableProjects={mockAvailableProjects}
				on:projectSwitched={handleProjectSwitched}
			/>
		</div>

		<Separator />

		<!-- User Profile Section -->
		<div>
			<h2 class="mb-4 text-xl font-semibold">Profile & Security</h2>
			<UserProfile user={mockUser} on:passwordChanged={handlePasswordChanged} />
		</div>
	</div>
</div>
