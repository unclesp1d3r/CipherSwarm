<script lang="ts">
	import { Alert, AlertDescription } from '$lib/components/ui/alert';
	import { Button } from '$lib/components/ui/button';
	import { AlertTriangle } from '@lucide/svelte';
	import { createEventDispatcher } from 'svelte';

	export let attackName: string;
	export let isConfirming = false;
	export let onconfirm: (() => void) | undefined = undefined;
	export let oncancel: (() => void) | undefined = undefined;

	const dispatch = createEventDispatcher<{
		confirm: void;
		cancel: void;
	}>();

	function handleConfirm() {
		if (onconfirm) {
			onconfirm();
		} else {
			dispatch('confirm');
		}
	}

	function handleCancel() {
		if (oncancel) {
			oncancel();
		} else {
			dispatch('cancel');
		}
	}
</script>

<Alert variant="destructive" class="mb-4">
	<AlertTriangle class="h-4 w-4" />
	<AlertDescription class="flex flex-col gap-3">
		<div>
			<strong>Warning:</strong> You are about to modify attack "{attackName}" which is
			currently running or has been exhausted. Editing this attack may affect ongoing
			operations.
		</div>
		<div class="flex gap-2">
			<Button variant="destructive" size="sm" onclick={handleConfirm} disabled={isConfirming}>
				{isConfirming ? 'Processing...' : 'Continue Anyway'}
			</Button>
			<Button variant="outline" size="sm" onclick={handleCancel}>Cancel</Button>
		</div>
	</AlertDescription>
</Alert>
