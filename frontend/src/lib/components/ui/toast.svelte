<script lang="ts">
  import { fade, fly } from 'svelte/transition';
  import { toastStore, type Toast } from '$lib/stores/toast.js';
  import Icon from './icon.svelte';
  import { cn } from '$lib/utils.js';

  let { toast }: { toast: Toast } = $props();

  // Get semantic colors and icons for different toast types
  function getToastStyles(type: Toast['type']) {
    switch (type) {
      case 'success':
        return {
          containerClass: 'bg-green-500/10 border-green-500/20 text-green-800 dark:text-green-200',
          iconClass: 'text-green-600 dark:text-green-400',
          icon: 'check-circle'
        };
      case 'error':
        return {
          containerClass: 'bg-red-500/10 border-red-500/20 text-red-800 dark:text-red-200',
          iconClass: 'text-red-600 dark:text-red-400', 
          icon: 'x-circle'
        };
      case 'warning':
        return {
          containerClass: 'bg-yellow-500/10 border-yellow-500/20 text-yellow-800 dark:text-yellow-200',
          iconClass: 'text-yellow-600 dark:text-yellow-400',
          icon: 'alert-triangle'
        };
      case 'info':
        return {
          containerClass: 'bg-blue-500/10 border-blue-500/20 text-blue-800 dark:text-blue-200',
          iconClass: 'text-blue-600 dark:text-blue-400',
          icon: 'info'
        };
      default:
        return {
          containerClass: 'bg-muted border-border text-foreground',
          iconClass: 'text-muted-foreground',
          icon: 'info'
        };
    }
  }

  const styles = getToastStyles(toast.type);

  function dismiss() {
    toastStore.remove(toast.id);
  }
</script>

<div
  class={cn(
    'relative flex items-start gap-3 rounded-md border p-4 shadow-lg backdrop-blur-sm',
    'transition-all duration-300 ease-in-out',
    styles.containerClass
  )}
  transition:fly={{ y: -50, duration: 300 }}
  role="alert"
  aria-live="polite"
>
  <!-- Icon -->
  <div class="flex-shrink-0">
    <Icon 
      name={styles.icon} 
      size="md" 
      class={styles.iconClass}
    />
  </div>

  <!-- Content -->
  <div class="flex-1 min-w-0">
    <h4 class="text-sm font-medium leading-5">
      {toast.title}
    </h4>
    {#if toast.message}
      <p class="mt-1 text-sm opacity-90">
        {toast.message}
      </p>
    {/if}
  </div>

  <!-- Dismiss button -->
  {#if toast.dismissible}
    <button
      onclick={dismiss}
      class="flex-shrink-0 rounded-md p-1 transition-colors hover:bg-black/5 dark:hover:bg-white/5 focus:outline-none focus:ring-2 focus:ring-accent"
      aria-label="Dismiss notification"
    >
      <Icon 
        name="close" 
        size="sm" 
        class="opacity-60 hover:opacity-100"
      />
    </button>
  {/if}
</div>