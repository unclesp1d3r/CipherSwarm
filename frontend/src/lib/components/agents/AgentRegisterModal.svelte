<script lang="ts">
	import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '../ui/dialog';
	import { Button } from '../ui/button';
	import { Input } from '../ui/input';
	import { Label } from '../ui/label';
	import { Alert } from '../ui/alert';

	export let open: boolean = false;
	export let onClose: () => void;
	export let onRegister: (payload: {
		display_name: string;
		host_name: string;
		config?: Record<string, string>;
	}) => void;

	let displayName: string = '';
	let hostName: string = '';
	let error: string | null = null;
	let submitting: boolean = false;

	function reset() {
		displayName = '';
		hostName = '';
		error = null;
		submitting = false;
	}

	$: if (!open) reset();

	function handleSubmit() {
		if (!displayName.trim()) {
			error = 'Display Name is required.';
			return;
		}
		if (!hostName.trim()) {
			error = 'Host Name is required.';
			return;
		}
		submitting = true;
		error = null;
		onRegister?.({ display_name: displayName.trim(), host_name: hostName.trim() });
	}
</script>

<Dialog {open}>
	<DialogContent class="w-full max-w-md">
		<DialogHeader>
			<DialogTitle>Register New Agent</DialogTitle>
		</DialogHeader>
		<form on:submit|preventDefault={handleSubmit} class="space-y-4">
			<div>
				<Label for="display_name">Display Name</Label>
				<Input
					id="display_name"
					type="text"
					bind:value={displayName}
					placeholder="Agent label"
					required
				/>
			</div>
			<div>
				<Label for="host_name">Host Name</Label>
				<Input
					id="host_name"
					type="text"
					bind:value={hostName}
					placeholder="Hostname or identifier"
					required
				/>
			</div>
			{#if error}
				<Alert variant="destructive">{error}</Alert>
			{/if}
			<DialogFooter class="mt-4 flex justify-end gap-2">
				<button type="button" class="btn-secondary" on:click={onClose}>Cancel</button>
				<Button type="submit" disabled={submitting}>Register</Button>
			</DialogFooter>
		</form>
	</DialogContent>
</Dialog>

<style>
	/* Add any component-specific styles here if needed */
</style>
