<script lang="ts">
  import * as LucideIcons from '@lucide/svelte';
  import { cn } from '$lib/utils.js';
  import { ATTACK_TYPE_ICONS, type AttackTypeIcon } from '$lib/utils/icons.js';

  interface IconProps {
    name: AttackTypeIcon | string;
    size?: 'sm' | 'md' | 'lg' | 'xl';
    class?: string;
  }

  let { name, size = 'md', class: className = '', ...restProps }: IconProps = $props();

  // Map size to actual pixel values
  const sizeMap = {
    sm: 16,
    md: 20, 
    lg: 24,
    xl: 32
  };

  // Get the icon name from our mapping or use as-is
  const iconName = ATTACK_TYPE_ICONS[name as keyof typeof ATTACK_TYPE_ICONS] || name;
  
  // Convert kebab-case to PascalCase for Lucide component names
  const componentName = iconName
    .split('-')
    .map((word: string) => word.charAt(0).toUpperCase() + word.slice(1))
    .join('') as keyof typeof LucideIcons;

  // Get the Lucide component - use derived for reactivity
  const IconComponent = $derived(LucideIcons[componentName] || LucideIcons.HelpCircle);
  
  const iconSize = sizeMap[size];
  const classes = cn('inline-block', className);
</script>

<!-- Using svelte:component is fine - warning can be ignored for now -->
<svelte:component 
  this={IconComponent} 
  size={iconSize}
  class={classes}
  {...restProps}
/>