# 🛠️ CipherSwarm Template Salvage Plan (HTMX → SvelteKit)

This document lists all templates in `templates/**/*.html.j2` and provides a recommendation for each: **Refactor as Svelte component** (with context) or **Discard** (with rationale). Use this as a migration checklist for the SvelteKit UI rewrite.

---

## Dashboard & Layout

- [ ] **base.html.j2** → **Refactor as SvelteKit layout**
  - _Context_: Provides navigation, layout, and global structure. Should become `+layout.svelte` and `Sidebar`, `Header`, and `Toast` components using Shadcn-Svelte. Remove all HTMX/Alpine/Flowbite JS. Navigation links and user menu should be Svelte stores and role-aware.
- [ ] **dashboard.html.j2** → **Refactor as Svelte page**
  - _Context_: Maps directly to the v2 Dashboard UX. Cards (Active Agents, Running Tasks, Cracked Hashes, Resource Usage) become Svelte components with live data via WebSocket. Recent Activity and Active Tasks sections should be Svelte tables fed by stores. Remove all Jinja/HTMX logic.

---

## Agents

- [ ] **agents/list.html.j2** → **Refactor as Svelte page**
  - _Context_: Agent list/table, filters, and actions map to the Agent Status Sheet and Agent List views. Use Svelte table, filter/search as reactive stores, and modal for registration. Actions (Details, Shutdown) become Svelte modals/dialogs.
- [ ] **agents/details_modal.html.j2** → **Refactor as Svelte modal**
  - _Context_: Agent detail modal, including device toggles and advanced config, should be a Svelte modal/dialog. All forms become Svelte forms with validation. Device toggles and config are admin-only.
- [ ] **agents/register_modal.html.j2** → **Refactor as Svelte modal**
  - _Context_: Agent registration modal. Use Svelte form, validation, and modal dialog. Remove all HTMX.
- [ ] **agents/table_fragment.html.j2**/**row_fragment.html.j2**/**benchmarks_fragment.html.j2**/**hardware_fragment.html.j2**/**performance_fragment.html.j2**/**error_log_fragment.html.j2** → **Refactor as Svelte components**
  - _Context_: These fragments are used in agent detail/status views. Each should become a Svelte component (e.g., AgentBenchmarks, AgentHardware, AgentPerformance, AgentErrorLog) and be composed in the Agent modal/page.

---

## Campaigns

- [ ] **campaigns/list.html.j2** → **Refactor as Svelte page**
  - _Context_: Campaign list view. Use Svelte table, filters, and pagination. Maps to Campaign Overview List in dashboard-ux.md.
- [ ] **campaigns/detail.html.j2** → **Refactor as Svelte page**
  - _Context_: Campaign detail view, including attack table. Attack rows/actions map to Svelte components. Use Svelte accordion for attack rows.
- [ ] **campaigns/editor_modal.html.j2**/**form.html.j2**/**delete_confirm.html.j2** → **Refactor as Svelte modals/forms**
  - _Context_: Campaign create/edit/delete flows. Use Svelte forms and dialogs.
- [ ] **campaigns/progress_fragment.html.j2**/**metrics_fragment.html.j2** → **Refactor as Svelte components**
  - _Context_: Progress and metrics widgets for campaign detail. Use Svelte stores for live updates.

---

## Attacks

- [ ] **attacks/list.html.j2** → **Refactor as Svelte page**
  - _Context_: Attack list for a campaign. Table layout, row actions, and modals map to Svelte components. See campaign_list_view.md.
- [ ] **attacks/editor_modal.html.j2**/**view_modal.html.j2** → **Refactor as Svelte modals**
  - _Context_: Attack editor/view modals. Use Svelte forms, validation, and modal dialogs. All attack mode editors (dictionary, mask, brute-force) should be Svelte components, referencing the attack editor notes.
- [ ] **attacks/brute_force_preview_fragment.html.j2**/**live_updates_toggle_fragment.html.j2**/**performance_summary_fragment.html.j2**/**estimate_fragment.html.j2**/**validate_summary_fragment.html.j2**/**attack_table_body.html.j2** → **Refactor as Svelte components**
  - _Context_: Used in attack editor and attack list. Each fragment becomes a Svelte component (e.g., BruteForcePreview, LiveUpdatesToggle, PerformanceSummary, Estimate, ValidateSummary, AttackTableBody).

---

## Resources

- [ ] **resources/list_fragment.html.j2** → **Refactor as Svelte page/component**
  - _Context_: Resource list/table, filters, and pagination. Use Svelte table and stores. Maps to resource management UI in dashboard-ux.md.
- [ ] **resources/detail_fragment.html.j2**/**preview_fragment.html.j2**/**content_fragment.html.j2**/**lines_fragment.html.j2**/**line_row_fragment.html.j2**/**rulelist_dropdown_fragment.html.j2**/**wordlist_dropdown_fragment.html.j2** → **Refactor as Svelte components**
  - _Context_: Resource detail/preview, dropdowns, and line views. Each fragment becomes a Svelte component.

---

## Users

- [ ] **users/list.html.j2** → **Refactor as Svelte page**
  - _Context_: User management table, filters, and actions. Use Svelte table, stores, and modals for edit/delete. Admin-only.
- [ ] **users/detail.html.j2**/**create_form.html.j2** → **Refactor as Svelte components**
  - _Context_: User detail and create form. Use Svelte forms and modals.

---

## Projects

- [ ] **projects/list.html.j2** → **Refactor as Svelte page**
  - _Context_: Project list/table, filters, and pagination. Use Svelte table and stores. Maps to project selector in dashboard-ux.md.
- [ ] **projects/project_info.html.j2** → **Refactor as Svelte component**
  - _Context_: Project info card/detail. Use Svelte component.

---

## Fragments (General UI)

- [ ] **fragments/alert.html.j2** → **Refactor as Svelte component**
  - _Context_: Alert/toast/notification. Use Shadcn-Svelte Toast or Alert component.
- [ ] **fragments/rule_explanation_modal.html.j2**/**profile.html.j2**/**context.html.j2**/**attack_edit_warning.html.j2** → **Refactor as Svelte components**
  - _Context_: Used in various modals and detail views. Each should be a Svelte component/modal as appropriate.

---

## Templates to Discard

- [ ] **Any template whose only purpose is HTMX partial update, or is tightly coupled to server-side Jinja/HTMX logic**
  - _Rationale_: SvelteKit will handle all UI updates client-side. Any template that only exists for HTMX fragment swaps, or is not referenced in the v2 UI notes, should be deleted.
- [ ] **All inline scripts, Alpine.js, and Flowbite JS usage**
  - _Rationale_: All interactivity and state will be handled by Svelte. Remove all legacy JS and HTMX attributes.

---

## General Notes

- All forms, tables, and modals should use SvelteKit idioms, Shadcn-Svelte, and Flowbite Svelte components.
- All data should be loaded via SvelteKit endpoints and Svelte stores, not via HTMX or Jinja.
- All role-based access and admin-only features should be implemented using SvelteKit's session/auth store.
- Use the UI screen notes in `docs/v2_rewrite_implementation_plan/notes/ui_screens/` for detailed component requirements and design references.

---

**This checklist should be updated as templates are refactored or deleted.** 