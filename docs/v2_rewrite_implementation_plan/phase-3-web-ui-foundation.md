# Phase 3: Web UI Foundation (Rewritten for SvelteKit)

This phase finalizes the web-based UI for CipherSwarm using a modern JSON API architecture and a SvelteKit frontend. During Phase 2, many backend endpoints were completed. Phase 3 ensures the SvelteKit frontend is integrated cleanly, consumes JSON from `/api/v1/web/*`, and is styled with Flowbite Svelte and DaisyUI. All user-visible routes must include proper Playwright E2E tests.

Skirmish is responsible for implementing all views from scratch in SvelteKit using only JSON APIs. No templates from Phase 2 will be reused. This phase includes full component layout, state management, validation, and test coverage.

---

## ✅ Summary

-   Backend endpoints are complete
-   All UI must be implemented using SvelteKit
-   No HTML templates from Phase 2 should be used
-   All frontend views must have corresponding Playwright-based E2E tests

---

## 🧱 Implementation Tasks

### General Frontend Setup

-   [ ] Create `frontend/` using SvelteKit + TypeScript + Tailwind + DaisyUI + Flowbite Svelte
-   [ ] Configure `tailwind.config.cjs` with Catppuccin Macchiato + DarkViolet accent
-   [ ] Use `@sveltejs/adapter-static` for offline-capable static output
-   [ ] Add dark mode toggle using DaisyUI utilities
-   [ ] Implement shared layout with sidebar, topbar, modal container, and toast container
-   [ ] Use `/api/v1/web/auth/context` to hydrate layout and navigation
-   [ ] Create navigation with role-aware links
-   [ ] Wire WebSocket listeners for:

    -   `/api/v1/web/live/agents`
    -   `/api/v1/web/live/campaigns`
    -   `/api/v1/web/live/toasts`

-   [ ] Define global types in `src/lib/types.ts` for all shared model shapes (Attack, Campaign, Agent, etc.)
-   [ ] Create typed `load()` functions for each route

### Agent UI Implementation

-   [ ] Build agent list view with columns: name + OS, status, temp, utilization, guess rate, current job
-   [ ] Add gear menu per row (admin-only) with options: disable agent, view details
-   [ ] Implement agent registration modal with label + project toggles
-   [ ] Render agent detail page with tabs:

    -   Settings (label, enabled, interval, native hashcat, benchmark toggle, project assignment, sysinfo)
    -   Hardware (device toggles, restart strategy, hardware flags)
    -   Performance (line charts per device, utilization donuts, temp readouts)
    -   Logs (realtime error log timeline with severity icons)
    -   Capabilities (benchmark table with toggle, search, category filters)

-   [ ] Hook up real-time updates for performance and task status via WebSocket or polling
-   [ ] Add E2E coverage for agent CRUD and detail views

### Attack Editor Implementation

-   [ ] Create dictionary editor modal:

    -   Min/max length
    -   Searchable wordlist dropdown
    -   Modifier buttons (+Change Case, etc.)
    -   Preview of ephemeral list
    -   “Previous Passwords” option

-   [ ] Create mask editor modal:

    -   Add/Remove masks
    -   Inline validation

-   [ ] Create brute force editor modal:

    -   Checkbox character classes
    -   Min/max length
    -   Mask generation

-   [ ] Live update estimated keyspace and complexity via `/attacks/estimate`
-   [ ] Show warning + reset if editing `running` or `exhausted` attacks
-   [ ] Allow JSON export/import of attack or campaign
-   [ ] Validate imported schema (versioned), rehydrate ephemeral lists, re-associate by GUID
-   [ ] Add E2E coverage for all attack types and import/export

### Campaign View Implementation

-   [ ] Build CampaignAttackRow\.svelte with summary: type, config, keyspace, complexity, comment
-   [ ] Campaign toolbar with buttons: add attack, sort, bulk-select/delete, start/stop toggle
-   [ ] Campaign view with drag-and-drop ordering and keyboard support
-   [ ] Context menu per attack row: edit, duplicate, delete, move up/down/top/bottom
-   [ ] Refresh campaign/attack progress live via WebSocket or polling
-   [ ] Show cracked hash toasts (batched if >5/sec)
-   [ ] Add E2E test for campaign list, dashboard, attack actions

### Resource UI

-   [ ] List resources and show metadata
-   [ ] Upload files via presigned URLs
-   [ ] Resource line editor for masks/rules with:

    -   Inline validation
    -   Add/remove rows
    -   Realtime feedback from 422 error response model

-   [ ] E2E coverage: resource CRUD, editing modes

### Toasts and Notifications

-   [ ] Global toast container using Flowbite
-   [ ] Hook up cracked hash events via WebSocket
-   [ ] Batch multiple events into summary toast
-   [ ] E2E tests for toast appearance and rate limits

---

## 🎨 Visual Theme

-   Catppuccin Macchiato base
-   DarkViolet accent (`#9400D3`)
-   Layout surfaces use `base`, `surface0`, `crust`
-   Flowbite + DaisyUI handle theme-compatible styling

---

## 🔧 DevOps & Build Tasks

-   [ ] Set up FastAPI to serve the compiled SvelteKit frontend using StaticFiles (served from `/static`, mounted at `/`)
-   [ ] Automate SvelteKit build process in Dockerfile (multi-stage: Node -> copy `build/` into backend image)
-   [ ] Ensure `just build-ui` builds the frontend and `just dev` includes frontend+backend integration
-   [ ] `frontend/` must build to `/static/`
-   [ ] FastAPI must serve built frontend via StaticFiles
-   [ ] Dockerfile must use multi-stage build: node → python
-   [ ] Add `just build-ui` and `just test-ui` targets

---

## 🔬 Testing Coverage

-   [ ] Vitest unit tests for all components
-   [ ] Playwright E2E for all routes and modals
-   [ ] Backend integration tests for `/api/v1/web/*` remain unchanged

---

> Reminder: This is a total UI rewrite. No legacy templates. All views must be reimplemented using SvelteKit and tested end-to-end. Use JSON APIs only. Do not duplicate backend logic.
