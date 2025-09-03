<script lang="ts">
  import { toastStore } from '$lib/stores/toast.js';
  import Toast from './toast.svelte';

  let toasts = $derived(toastStore.toasts);
</script>

<!-- Toast container with fixed positioning -->
<div 
  class="fixed top-4 right-4 z-50 flex flex-col gap-2 w-full max-w-sm"
  aria-live="polite"
  aria-label="Notifications"
>
  {#each toasts as toast (toast.id)}
    <Toast {toast} />
  {/each}
</div>