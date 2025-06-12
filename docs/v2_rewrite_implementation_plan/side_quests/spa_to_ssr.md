# 🔄 SPA to SSR Migration Plan - Task-Based Execution

## 📋 Overview

This document outlines the complete migration plan for transitioning CipherSwarm from a static SvelteKit SPA served by FastAPI to a fully decoupled, dynamic SvelteKit application with SSR capabilities.

**Current State:**

- SvelteKit app using `adapter-static` with `fallback: 'index.html'`  
- FastAPI serves frontend via `StaticFiles` mount at root (`/`)
- Frontend makes API calls using relative paths (`/api/v1/web/*`)
- No SSR, broken deep linking, limited form handling

**Target State:**

- SvelteKit app using `adapter-node` with SSR
- Decoupled frontend server consuming FastAPI as an API service
- Proper environment-based API configuration
- Full SSR, working deep links, SvelteKit form actions with Shadcn-Svelte + Superforms

## 🎯 Key Architectural Decision: "Stock Shadcn-Svelte" Approach

**Philosophy:** Leverage Superforms' built-in SvelteKit integration instead of custom API clients.

**Implementation Strategy:**

1. ✅ **Forms use standard SvelteKit form actions** (POST to same route)
2. ✅ **Superforms handles validation & progressive enhancement** (out-of-the-box)
3. ✅ **Server-side conversion** of validated data to CipherSwarm API format
4. ✅ **Components stay close to stock Shadcn-Svelte** patterns for maintainability

**Benefits:**

- Minimal custom code to maintain
- Maximum compatibility with Shadcn-Svelte ecosystem updates
- Progressive enhancement works automatically
- Clean separation between form concerns and API concerns

---

## 📝 TASK EXECUTION PLAN

### Phase 1: Foundation Setup

#### 1.1 Update Dependencies and Configuration

- [x] **Update SvelteKit Adapter** `task_id: setup.adapter_update`
- [ ] **Update Dependencies for Shadcn-Svelte Ecosystem** `task_id: setup.dependencies_update`
- [ ] **Update Vite Configuration** `task_id: setup.vite_config`

#### 1.2 Environment Setup

- [ ] **Create Environment Files** `task_id: setup.environment_files`
- [ ] **Create Type-Safe Configuration** `task_id: setup.config_file`

#### 1.3 API Integration Setup

- [ ] **Create Server-Side API Client** `task_id: setup.server_api_client`
- [ ] **Create Simple Client-Side API Wrapper** `task_id: setup.client_api_wrapper`

### Phase 2: Backend Configuration Updates

- [ ] **Update FastAPI Configuration** `task_id: backend.remove_static_serving`

### Phase 3: Route Migration (Data Loading)

#### 3.1 Dashboard Route

- [ ] **`frontend/src/routes/+page.svelte`** (Dashboard/Home) `task_id: dashboard.overall`

#### 3.2 Campaign Routes

- [ ] **`frontend/src/routes/campaigns/+page.svelte`** `task_id: campaigns.overall`
- [ ] **`frontend/src/routes/campaigns/[id]/+page.svelte`** `task_id: campaigns.detail`

#### 3.3 Other Main Routes

- [ ] **`frontend/src/routes/attacks/+page.svelte`** `task_id: attacks.overall`
- [ ] **`frontend/src/routes/projects/+page.svelte`** `task_id: projects.overall`
- [ ] **`frontend/src/routes/users/+page.svelte`** `task_id: users.overall`
- [ ] **`frontend/src/routes/resources/+page.svelte`** `task_id: resources.overall`
- [ ] **`frontend/src/routes/resources/[id]/+page.svelte`** `task_id: resources.detail`
- [ ] **`frontend/src/routes/agents/+page.svelte`** `task_id: agents.overall`
- [ ] **`frontend/src/routes/settings/+page.svelte`** `task_id: settings.overall`

### Phase 4: High-Priority Form Migration

#### 4.1 Campaign Form Migration

- [ ] **`CampaignEditorModal.svelte`** `task_id: campaigns.editor_modal`

#### 4.2 Attack Form Migration

- [ ] **`AttackEditorModal.svelte`** (Complex - 24KB) `task_id: attacks.editor_modal`

#### 4.3 User Form Migration

- [ ] **`UserCreateModal.svelte`** `task_id: users.create_modal`
- [ ] **`UserDetailModal.svelte`** `task_id: users.detail_modal`

### Phase 5: Complex Form Migration

#### 5.1 File Upload Form

- [ ] **`CrackableUploadModal.svelte`** (Very Complex - 32KB) `task_id: crackable_upload.overall`

### Phase 6: Component Data Loading Migration

#### 6.1 Campaign Component Data Loading

- [ ] **Campaign Data Loading** `task_id: campaigns.data_loading`

#### 6.2 Attack Component Data Loading

- [ ] **Attack Data Loading** `task_id: attacks.data_loading`

#### 6.3 Resource Component Data Loading

- [ ] **Resource Data Loading** `task_id: resources.data_loading`

#### 6.4 User & Project Component Data Loading

- [ ] **User & Project Data Loading** `task_id: users_and_projects.data_loading`

### Phase 7: Medium-Priority Forms

#### 7.1 Delete Confirmation Forms

- [ ] **`UserDeleteModal.svelte`** `task_id: users.delete_modal`
- [ ] **`CampaignDeleteModal.svelte`** `task_id: campaigns.delete_modal`

### Phase 8: Development Environment Setup

#### 8.1 Docker Configuration

- [ ] **Update Docker Configuration** `task_id: docker.setup`

#### 8.2 Development Commands

- [ ] **Update Justfile Commands** `task_id: justfile.update`

### Phase 9: Testing Setup

#### 9.1 Component Tests

- [ ] **Update Component Tests** `task_id: tests.component_update`

#### 9.2 E2E Tests

- [ ] **Update E2E Tests** `task_id: tests.e2e_update`

#### 9.3 Automated Testing Implementation

- [ ] **SSR Content Verification Tests** `task_id: verify.automated_ssr_content_tests`
- [ ] **Hydration Testing** `task_id: verify.automated_ssr_hydration_tests`
- [ ] **API Integration Testing** `task_id: verify.automated_ssr_api_integration_tests`

### Phase 10: Verification & Validation

#### 10.1 Manual SSR Verification

- [ ] **Manual SSR Testing** `task_id: verify.manual_ssr_testing`

#### 10.2 Development Environment Verification

- [ ] **Local Development Verification** `task_id: verify.dev_environment`

#### 10.3 Production Environment Verification

- [ ] **Docker Deployment Verification** `task_id: verify.production_environment`

#### 10.4 Shadcn-Svelte Integration Verification

- [ ] **Superforms v2 Integration Verification** `task_id: verify.superforms_integration`
- [ ] **Formsnap Component Verification** `task_id: verify.formsnap_components`
- [ ] **Zod Schema Verification** `task_id: verify.zod_schemas`

#### 10.5 Final Migration Verification

- [ ] **Architectural Verification** `task_id: verify.architecture_approach`
- [ ] **Migration Completion Verification** `task_id: verify.migration_complete`

---

## 📚 Technical Implementation Details

### Stock Shadcn-Svelte Form Example

```svelte
<!-- frontend/src/routes/campaigns/new/+page.svelte -->
<script lang="ts">
 import { superForm } from 'sveltekit-superforms';
 import { zodClient } from 'sveltekit-superforms/adapters';
 import { Field, Control, Label, FieldErrors } from 'formsnap';
 import { Button } from '$lib/components/ui/button';
 import { Input } from '$lib/components/ui/input';
 import { campaignSchema } from './schema';
 
 export let data;

 // Pure Superforms - no custom API integration
 const { form, errors, enhance, submitting } = superForm(data.form, {
  validators: zodClient(campaignSchema)
 });
</script>

<!-- Standard SvelteKit form - POSTs to same route -->
<form method="POST" use:enhance>
 <Field name="name" form={form}>
  <Control let:attrs>
   <Label>Campaign Name</Label>
   <Input {...attrs} bind:value={$form.name} />
  </Control>
  <FieldErrors />
 </Field>

 <Button type="submit" disabled={$submitting}>
  {$submitting ? 'Creating...' : 'Create Campaign'}
 </Button>
</form>
```

### Clean Server Action Pattern

```typescript
// frontend/src/routes/campaigns/new/+page.server.ts
import { superValidate } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';
import { fail, redirect } from '@sveltejs/kit';
import { campaignSchema } from './schema';
import { serverApi, convertCampaignData } from '$lib/server/api';
import type { Actions, PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ cookies }) => {
 // Initialize form with Superforms
 const form = await superValidate(zod(campaignSchema));
 return { form };
};

export const actions: Actions = {
 default: async ({ request, cookies }) => {
  // Superforms handles validation
  const form = await superValidate(request, zod(campaignSchema));
  
  if (!form.valid) {
   return fail(400, { form });
  }
  
  try {
   // Convert Superforms data → CipherSwarm API format
   const apiPayload = convertCampaignData(form.data);
   
   // Call backend API
   const campaign = await serverApi.post('/api/v1/web/campaigns/', apiPayload, {
    Cookie: cookies.get('sessionid') || ''
   });
   
   return redirect(303, `/campaigns/${campaign.id}`);
  } catch (error) {
   return fail(500, { form, message: 'Failed to create campaign' });
  }
 }
};
```

### Migration Verification Script

```bash
#!/bin/bash
# Check migration completion

echo "🔍 Checking for remaining axios usage..."
grep -r "axios\." frontend/src/routes/ || echo "✅ No axios in routes"

echo "🔍 Checking for remaining createEventDispatcher in forms..."
grep -r "createEventDispatcher" frontend/src/lib/components/*/Modal.svelte || echo "✅ No dispatchers in modals"

echo "🔍 Checking for server actions..."
find frontend/src/routes -name "+page.server.ts" | wc -l
echo "Server action files found"

echo "🔍 Running tests..."
cd frontend && pnpm test && pnpm exec playwright test
```

---

**Benefits of This Task-Based Approach:**

1. **Clear Sequential Execution** - Each phase builds on the previous
2. **Granular Task IDs** - Easy to grep and find next unchecked task  
3. **Logical Grouping** - Related tasks are grouped together
4. **Verification Built-In** - Testing and verification throughout
5. **Minimal Custom Code** - Leverage Superforms' built-in SvelteKit features
6. **Easy Maintenance** - Stays close to Shadcn-Svelte documentation
7. **Progressive Enhancement** - Works without JavaScript by default
8. **Clean Separation** - Form logic vs. API conversion are separate concerns
9. **Type Safety** - End-to-end type safety with minimal complexity
