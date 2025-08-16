---
inclusion: fileMatch
fileMatchPattern: [frontend/**/*, docs/v2_rewrite_implementation_plan/phase-3-web-ui-implementation/*.md]
---

# SvelteKit 5 Runes Implementation Guide

## Overview

This rule provides comprehensive guidelines for implementing SvelteKit 5 runes correctly, based on lessons learned from migrating stores from Svelte 4 patterns to SvelteKit 5 runes.

## Critical Constraints

### File Extensions for Runes

- **MUST use `.svelte.ts` files** for stores that use runes (`$state`, `$derived`, `$effect`)
- **CANNOT use regular `.ts` files** with runes - they will cause build errors
- **Example:** `campaigns.svelte.ts`, `attacks.svelte.ts`, `resources.svelte.ts`

### Export Patterns

- **NEVER export `$derived` values directly** from modules:

```typescript
// ❌ WRONG - This breaks SvelteKit 5
export const campaigns = $derived(campaignState.campaigns);

// ✅ CORRECT - Use functions that return derived values
const campaigns = $derived(campaignState.campaigns);
export function getCampaigns() {
    return campaigns;
}
```

### Store Object Pattern

- **Preferred approach:** Export store objects with getter methods:

```typescript
export const campaignsStore = {
    // Getters for reactive state
    get campaigns() {
        return campaignState.campaigns;
    },
    get loading() {
        return campaignState.loading;
    },
    
    // Actions
    async loadCampaigns() {
        // Implementation
    }
};
```

## Rune Usage Patterns

### State Management

```typescript
// ✅ CORRECT - Object wrapper for boolean reactivity
const loadingState = $state({ value: false });

// ✅ CORRECT - Direct primitive state
const campaigns = $state<Campaign[]>([]);
```

### Derived Values

```typescript
// ✅ CORRECT - Module-level derived values
const filteredCampaigns = $derived(
    campaigns.filter(c => c.status === 'active')
);
```

### Effects for SSR Hydration

```typescript
// ✅ CORRECT - Use $effect for reactive SSR data updates
$effect(() => {
    if (data.campaigns) {
        campaignState.campaigns = data.campaigns;
    }
});
```

## Component Integration

### Props Pattern

```svelte
<script lang="ts">
    // ✅ CORRECT - Use $props() for component props
    let { campaign, onUpdate }: { 
        campaign: Campaign; 
        onUpdate?: (campaign: Campaign) => void 
    } = $props();
</script>
```

### Store Usage in Components

```svelte
<script lang="ts">
    import { campaignsStore } from '$lib/stores/campaigns.svelte';
    
    // ✅ CORRECT - Access store state directly
    let campaigns = $derived(campaignsStore.campaigns);
    let loading = $derived(campaignsStore.loading);
</script>
```

## SSR Integration

### Page Data Usage

```svelte
<!-- ✅ CORRECT - Use SSR data directly in pages -->
<script lang="ts">
    export let data: PageData;
    
    // Use SSR data directly, not store data
    let campaigns = $derived(data.campaigns.items);
    let totalCount = $derived(data.campaigns.total_count);
</script>
```

### Store Hydration (When Needed)

```typescript
// Only hydrate stores when components need reactive updates
$effect(() => {
    if (data.campaigns) {
        campaignsStore.hydrateCampaigns(data.campaigns);
    }
});
```

## Testing Considerations

### Mock Store Setup

```typescript
// ✅ CORRECT - Mock the .svelte.ts file path
vi.mock('$lib/stores/campaigns.svelte', () => ({
    campaignsStore: {
        getCampaigns: vi.fn(),
        loading: vi.fn(),
        // ... other methods
    }
}));
```

### Test File Constraints

- **Cannot test runes in regular `.ts` test files**
- **Delete test files that directly test rune functionality**
- **Test runes through component tests instead**

## Migration Patterns

### From Svelte 4 Stores

```typescript
// ❌ OLD - Svelte 4 pattern
import { writable, derived } from 'svelte/store';
export const campaigns = writable([]);
export const loading = derived(campaigns, $campaigns => $campaigns.length === 0);

// ✅ NEW - SvelteKit 5 runes pattern
const campaignState = $state({ campaigns: [], loading: false });
const campaigns = $derived(campaignState.campaigns);
const loading = $derived(campaignState.loading);

export const campaignsStore = {
    get campaigns() { return campaigns; },
    get loading() { return loading; },
    // ... actions
};
```

### Component Migration

```svelte
<!-- ❌ OLD - Reactive statements -->
<script>
    $: filteredCampaigns = campaigns.filter(c => c.active);
</script>

<!-- ✅ NEW - Derived runes -->
<script>
    let filteredCampaigns = $derived(campaigns.filter(c => c.active));
</script>
```

## Common Pitfalls

### Runtime Errors

- **Issue:** Exporting `$derived` directly causes "Cannot export reactive state" errors
- **Fix:** Use getter functions or store object pattern

### Build Errors

- **Issue:** Using runes in `.ts` files causes TypeScript errors
- **Fix:** Rename to `.svelte.ts` and update all imports

### Test Failures

- **Issue:** Tests fail because they can't import runes from `.ts` files
- **Fix:** Update test imports to use `.svelte.ts` paths and test through components

## Best Practices

1. **Always use `.svelte.ts` for rune-based stores**
2. **Export store objects with getters, not direct rune values**
3. **Use SSR data directly in pages when possible**
4. **Only hydrate stores when components need reactive updates**
5. **Test runes through component integration, not unit tests**
6. **Update all import paths when migrating from `.ts` to `.svelte.ts`**

## File References

- Store examples: [campaigns.svelte.ts](mdc:CipherSwarm/CipherSwarm/frontend/src/lib/stores/campaigns.svelte.ts)
- Component usage: [CampaignProgress.svelte](mdc:CipherSwarm/CipherSwarm/frontend/src/lib/components/campaigns/CampaignProgress.svelte)
- SSR integration: [+page.svelte](mdc:CipherSwarm/CipherSwarm/frontend/src/routes/campaigns/+page.svelte)
