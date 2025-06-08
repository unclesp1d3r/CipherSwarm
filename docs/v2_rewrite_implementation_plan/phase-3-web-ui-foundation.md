# Phase 3: Web UI Foundation (Rewritten for SvelteKit)

This phase finalizes the web-based UI for CipherSwarm using a modern JSON API architecture and a SvelteKit frontend. During Phase 2, many backend endpoints were completed. Phase 3 ensures the SvelteKit frontend is integrated cleanly, consumes JSON from `/api/v1/web/*`, and is styled with Flowbite Svelte and DaisyUI. All user-visible routes must include proper Playwright E2E tests.

Skirmish is responsible for implementing all views from scratch in SvelteKit using only JSON APIs. No templates from Phase 2 will be reused. This phase includes full component layout, state management, validation, and test coverage.

Many of the components are already implemented, but need to be styled, wired up to the backend, and full tests need to be written in playwright to validate the functionality complete functionality.

A new test-seeding endpoint needs to be created in the backend to seed the database with the necessary data for the e2e tests. The existing e2e tests that rely on mock data need to be reclassified as integration tests, and new e2e tests need to be written that fully validate the functionality of the frontend and the backend together.

---

## ✅ Summary

- Backend endpoints are complete
- All UI must be implemented using SvelteKit
- All HTML templates from Phase 2 should have been converted to SvelteKit components and the tests relying on mock data should be reclassified as integration tests.
- New e2e tests need to be written that fully validate the functionality of the frontend and the backend together that replicate all of the existing e2e tests, but relying on the new test-seeding endpoint to seed the database with the necessary data and then validate the functionality of the frontend and the backend together.
- All frontend views must have corresponding Playwright-based E2E tests

---

## 🧱 Implementation Tasks

### General Frontend Setup

- [x] Create `frontend/` using SvelteKit + TypeScript + Tailwind + adapter-static + eslint + prettier + vitest + playwright
- [x] Install `shadcn-svelte@next` to support SvelteKit 5 and Tailwind 4 using `pnpm` in `frontend/`
- [ ] Configure `frontend/app.css` with Catppuccin Macchiato + DarkViolet accent (see `docs/development/style-guide.md` for style guide)
- [ ] Add dark mode toggle using Shadcn-Svelte (<https://ui.shadcn.com/docs/themes/dark-mode>) utilities
- [ ] Implement shared layout with sidebar, topbar, modal container, and toast container (mostly done, just needs to validated and styled)
- [ ] Implement login page (with email + password)
- [ ] Implement account page (with password change)
- [ ] Implement settings page
- [ ] Create navigation with role-aware links
- [ ] Wire SSE listeners for:

  - `/api/v1/web/live/agents`
  - `/api/v1/web/live/campaigns`
  - `/api/v1/web/live/toasts`

- [ ] Define global types in `src/lib/types.ts` for all shared model shapes using Zod (Attack, Campaign, Agent, etc.)  (derived from backend models)
- [ ] Create typed `load()` functions for each route (derived from backend models using zod and axios using the types from `src/lib/types.ts`)

### Agent UI Implementation

- [ ] Build agent list view with columns: name + OS, status, temp, utilization, guess rate, current job
- [ ] Add gear menu per row (admin-only) with options: disable agent, view details
- [ ] Implement agent registration modal with label + project toggles
- [ ] Render agent detail page with tabs:

  - Settings (label, enabled, interval, native hashcat, benchmark toggle, project assignment, sysinfo)
  - Hardware (device toggles, restart strategy, hardware flags)
  - Performance (line charts per device, utilization donuts, temp readouts)
  - Logs (realtime error log timeline with severity icons)
  - Capabilities (benchmark table with toggle, search, category filters)

- [ ] Hook up real-time updates for performance and task status via SSE
- [ ] Add E2E coverage for agent CRUD and detail views

### Attack Editor Implementation

- [ ] Create dictionary editor modal (see `docs/v2_rewrite_implementation_plan/notes/ui_screens/new_dictionary_attack_editor.md`):

  - Min/max length
  - Searchable wordlist dropdown
  - Modifier buttons (+Change Case, etc.)
  - Preview of ephemeral list
  - “Previous Passwords” option

- [ ] Create mask editor modal (see `docs/v2_rewrite_implementation_plan/notes/ui_screens/new_mask_attack_editor.md`):

  - Add/Remove masks
  - Inline validation

- [ ] Create brute force editor modal (see `docs/v2_rewrite_implementation_plan/notes/ui_screens/brute_force_attack_editor.md`):

  - Checkbox character classes
  - Min/max length
  - Mask generation

- [ ] Live update estimated keyspace and complexity via `/api/v1/web/attacks/estimate`
- [ ] Show warning + reset if editing `running` or `exhausted` attacks
- [ ] Allow JSON export/import of attack or campaign
- [ ] Validate imported schema (versioned), rehydrate ephemeral lists, re-associate by GUID
- [ ] Add E2E coverage for all attack types and import/export

### Campaign View Implementation

- [ ] Build CampaignAttackRow\.svelte with summary: type, config, keyspace, complexity, comment
- [ ] Campaign toolbar with buttons: add attack, sort, bulk-select/delete, start/stop toggle
- [ ] Campaign view with drag-and-drop ordering and keyboard support
- [ ] Context menu per attack row: edit, duplicate, delete, move up/down/top/bottom
- [ ] Refresh campaign/attack progress live via SSE
- [ ] Show cracked hash toasts (batched if >5/sec)
- [ ] Add E2E test for campaign list, dashboard, attack actions

### Resource UI

- [ ] List resources and show metadata
- [ ] Upload files via presigned URLs
- [ ] Resource line editor for masks/rules with:

  - Inline validation
  - Add/remove rows
  - Realtime feedback from 422 error response model

- [ ] E2E coverage: resource CRUD, editing modes

### Toasts and Notifications

- [ ] Global toast container using Flowbite
- [ ] Hook up cracked hash events via SSE
- [ ] Batch multiple events into summary toast
- [ ] E2E tests for toast appearance and rate limits

---

## 🎨 Visual Theme

- Catppuccin Macchiato base
- DarkViolet accent (`#9400D3`)
- Layout surfaces use `base`, `surface0`, `crust`
- Shadcn-Svelte handle theme-compatible styling

---

## 🔧 DevOps & Build Tasks

- [x] Set up FastAPI to serve the compiled SvelteKit frontend using StaticFiles (served from `frontend/build`, mounted at `/`)
- [ ] Automate SvelteKit build process in Dockerfile (multi-stage: Node -> copy `build/` into backend image)
- [x] Ensure `just build-frontend` builds the frontend and `just dev` includes frontend+backend integration
- [x] `frontend/` must build to `frontend/build/`
- [x] FastAPI must serve built frontend via StaticFiles
- [ ] Dockerfile must use multi-stage build: node → python
- [x] Add `just frontend-test` target

---

## 🔬 Testing Coverage

- [ ] Vitest unit tests for all components
- [ ] Playwright E2E for all routes and modals
- [ ] Backend integration tests for `/api/v1/web/*` remain unchanged

---

> Reminder: This is a total UI rewrite. No legacy templates. All views must be reimplemented using SvelteKit and tested end-to-end. Use JSON APIs only. Do not duplicate backend logic.
