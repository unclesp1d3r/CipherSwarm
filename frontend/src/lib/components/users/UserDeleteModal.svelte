<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import axios from 'axios';
	import { Dialog, DialogContent, DialogHeader, DialogTitle } from '$lib/components/ui/dialog';
	import { Button } from '$lib/components/ui/button';
	import type { User } from '$lib/types/user';

	export let user: User;
	export let onClose: () => void;
	export let onUserDeleted: () => void;

	const dispatch = createEventDispatcher();

	let loading = false;
	let error = '';

	async function handleDelete() {
		loading = true;
		error = '';

		try {
			await axios.delete(`/api/v1/web/users/${user.id}`);
			onUserDeleted();
		} catch (e: unknown) {
			error =
				(e as { response?: { data?: { detail?: string } } }).response?.data?.detail ||
				'Failed to deactivate user';
		} finally {
			loading = false;
		}
	}
</script>

<Dialog open={true} onOpenChange={onClose}>
	<DialogContent class="sm:max-w-md" data-testid="user-delete-modal">
		<DialogHeader>
			<DialogTitle>Deactivate User</DialogTitle>
		</DialogHeader>

		<div class="space-y-4">
			<p class="text-sm text-gray-600">
				Are you sure you want to deactivate the user <strong>{user.name}</strong>
				({user.email})?
			</p>

			<p class="text-sm text-gray-600">
				This will deactivate the user account, preventing them from logging in. This action
				can be reversed by reactivating the user.
			</p>

			{#if error}
				<div class="text-sm text-red-600" data-testid="error-message">{error}</div>
			{/if}

			<div class="flex justify-end gap-2">
				<Button variant="outline" onclick={onClose} data-testid="cancel-button">
					Cancel
				</Button>
				<Button
					variant="destructive"
					onclick={handleDelete}
					disabled={loading}
					data-testid="confirm-delete-button"
				>
					{loading ? 'Deactivating...' : 'Deactivate User'}
				</Button>
			</div>
		</div>
	</DialogContent>
</Dialog>
