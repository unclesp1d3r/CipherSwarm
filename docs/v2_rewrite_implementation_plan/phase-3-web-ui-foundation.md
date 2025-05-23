# Phase 3: Web UI Foundation (Updated)

This phase finalizes the web-based UI for CipherSwarm. Many backend and template components were implemented during Phase 2. Phase 3 ensures these components are fully integrated, connected with HTMX behaviors, styled with Flowbite, and covered by real browser-level Playwright tests.

Skirmish is responsible for stitching together incomplete fragments into fully functional pages, ensuring correct HTMX flows, implementing interactive behaviors, and adding required end-to-end tests. This includes rendering real data via the FastAPI Web UI API (`/api/v1/web/*`), handling user actions like modals, reorders, and updates, and wiring live refreshes via HTMX polling or WebSocket.

---

## [x] Summary

-   🧱 **Backend logic and most templates were created in Phase 2.**
-   🧪 **Most tasks in Phase 3 involve integrating, wiring, and testing these components.**
-   🧩 **All user-visible routes must have Playwright-based E2E tests.**

---

## 🧱 Core Setup

**🟣 NOTE:** Refer to the [🎨 Visual Theme & Mood](#-visual-theme--mood) section at the end of this document before styling components. This defines the base colors, accent, and layout surfaces expected across all views.

-   [x] HTMX is already wired in (`base.html`)
-   [ ] Flowbite is included (ensure offline/local inclusion)
-   [ ] Dark mode toggle exists
-   [ ] Integrate toast component into base layout. Wire to HTMX or WebSocket-based cracked hash events. Use `hx-sse` or polling approach from `/campaigns/{id}/progress` or cracked hash event routes.
-   [ ] Build a full Flowbite-based application shell in `base.html` using the [Sidebar + Navbar Shell layout](https://flowbite.com/blocks/application/shells/). Your shell must:

    -   [ ] Define persistent layout regions:

        -   `#sidebar`, `#topbar`, `#main`, `#toast-container`, `#modal-body`

    -   [ ] Include all shared scripts and styles (HTMX, Flowbite, custom JS/CSS if needed)
    -   [ ] Include dark mode toggle, remembering user preference via local storage or session cookie
    -   [ ] Hydrate sidebar and header via `/api/v1/web/auth/context` to show project name, user role, and role-aware links
    -   [ ] Make the sidebar **collapsible**, using Flowbite's [sidebar toggle control](https://flowbite.com/docs/components/sidebar/#with-collapse-button)
    -   [ ] Include Flowbite toast container (always rendered, wired to cracked hash updates)
    -   [ ] Register HTMX WebSocket extension and connect to:

        -   `/api/v1/web/live/agents`
        -   `/api/v1/web/live/campaigns`
        -   `/api/v1/web/live/toasts`

    -   [ ] Define a modal zone with `id="modal"` and `#modal-body` as a standard `hx-target` swap zone
    -   [ ] Optionally set `<body data-role="{{ user.role }}">` to enable scoped behavior or access control. Use context from `/api/v1/web/auth/context` and show/hide nav items accordingly. Fragments already exist in `nav/sidebar.html` and `nav/topbar.html`.

---

## 👤 User Management UI (Admin only)

-   [ ] Backend implemented (create/edit/delete/update/reset)
-   [ ] Modal forms and user listing templates exist
-   [ ] Write `e2e/test_users.py`: log in as admin, navigate to user list, open modal, create/edit/delete user, verify updates appear live. Use selectors to validate table contents and modal fields are bound correctly.

---

## ⚙️ Agent Management UI

-   [ ] All detail endpoints and fragments are implemented
-   [ ] Complete agent list page: show state, attempts/sec, temp, current job. Populate from `/api/v1/web/agents/`. Confirm `display_name = custom_label or host_name` logic is respected.
-   [ ] Enable live updates via HTMX polling or WS swap on agent list table. Pull from `/agents/{id}/performance` and `/agents/` aggregate view.
-   [ ] Finish stitching agent detail tabs: show tabbed view with settings, hardware, performance, log, capabilities (use HTMX tab controls; each tab should render a fragment).
-   [ ] Build E2E tests for agent registration and tabbed detail view (`e2e/test_agents.py`, `e2e/test_agent_detail.py`). Validate registration modal shows token only once and tabs load correct content.

---

## 📦 Hash List Management

-   [ ] Hashlist CRUD implemented
-   [ ] Crack result table + metadata available
-   [ ] Trigger toast when new cracked hash is reported via WebSocket or HTMX polling. Toast must show plaintext, hashlist name, and attack name.

💡 Add a rate-limiting or batching mechanism to prevent UI overload. If more than 5 hashes are cracked in 3 seconds, collapse them into a single toast or summary notification. This helps avoid flooding the UI in case of rapid cracking during a short attack run.

-   [ ] Implement confirmation modal and API call for relaunching failed attacks from hashlist view. Use `/campaigns/{id}/relaunch` endpoint.
-   [ ] Write E2E tests to cover hashlists, crack results, relaunch workflows (`e2e/test_hashlists.py`, `e2e/test_cracks.py`). Ensure both empty and populated lists are tested.

---

## 🎯 Attack Resource Management

-   [ ] Resource list, detail, and metadata editor exist
-   [ ] File uploads work via presigned S3 URLs
-   [ ] Implement interactive line editor for small mask/rule/wordlist resources using `/resources/{id}/lines`. Display validation icons and allow line addition/removal.
-   [ ] Add JS validation feedback per edited line using returned validation errors (422). Use the `ResourceLineValidationError` model for parsing.
-   [ ] Write E2E tests for editing and previewing resource lines (`e2e/test_resources.py`, `e2e/test_resource_edit.py`). Test editable and read-only resources separately.

---

## 📈 Campaign Monitor View

-   [ ] Backend campaign detail and metrics views exist
-   [ ] Attack table rows + gear menu support full editing
-   [ ] Campaign lifecycle toggles work
-   [ ] Implement HTMX polling or WebSocket refresh for campaign + attack progress. Endpoints: `/campaigns/{id}/progress`, `/attacks/{id}/performance`
-   [ ] Complete toast delivery logic for cracked hashes within campaign view. Use hashed-to-user filtering to limit notifications.
-   [ ] Write `e2e/test_campaigns.py` and `e2e/test_campaign_detail.py` to verify dashboard, campaign list, add/edit attacks, progress bar updates. Include test for "Move Up"/"Duplicate" buttons.

---

## 🔁 Relaunch / Wordlist Modification

-   [ ] Backend rerun/relaunch endpoint works
-   [ ] Add modal to confirm relaunch request with description of what will be reprocessed. Include dynamic summary of affected attacks.
-   [ ] Wire modal to backend via HTMX form; update campaign view after submit. Resulting change should be visible via updated status/alerts.

---

## 🔔 Toast Notifications

-   [ ] Integrate toast infrastructure using Flowbite toasts. Place container in `base.html` and load it once.
-   [ ] Use HTMX event stream or polling to trigger cracked hash toasts. Reference `/campaigns/{id}/progress` as source.
-   [ ] Implement rate-limiting or batching to prevent alert spam. Group hashes by attack or display summary if > 3 in 5 seconds.

---

## 🧪 Playwright E2E Test Requirements

All public-facing Web UI pages must have a corresponding E2E test in `e2e/`. This includes:

-   Full pages (`/campaigns`, `/agents`, etc.)
-   Modal dialogs (`/attacks/new`, `/agents/register`)
-   Fragments (`/resources/{id}/preview`, `/campaigns/{id}/progress`)

Each test script should:

-   Be a standalone async Python script
-   Assert presence of key elements, interaction success
-   Be named `test_<thing>.py`
-   Run under `just test-frontend`

> **Example:** `e2e/test_campaigns.py` should:
>
> -   Visit `/campaigns`
> -   Assert campaign table rows exist
> -   Click "+ Add Attack", verify modal opens
> -   Submit dummy attack and check UI refresh

**NOTE:** Any UI task marked as complete must be covered by E2E or it will be considered incomplete.

---

## 📎 Notes for Skirmish

-   Avoid writing new backend logic unless absolutely required — assume backend is done
-   Use HTMX idioms (`hx-target`, `hx-swap`, `hx-trigger`) correctly on all modals, forms, and buttons
-   Prefer reusing fragments rather than duplicating HTML in base templates
-   Follow `test-guidelines.mdc` for Playwright structure and naming
-   All templates must work with both polling and WebSocket refresh where noted
-   Test each feature with a real running backend via the E2E suite
-   Check route-level source if unsure which endpoint powers which fragment (`campaigns.py`, `attacks.py`, `agents.py`, etc. in `/app/api/v1/endpoints/web/`)

---

## 🧩 UI Composition Tips for Skirmish

The following patterns should be used when wiring together HTMX, modals, and real-time UI elements in CipherSwarm. These reinforce the UX expectations from the attack editor specs and campaign mockups.

### 🔁 HTMX Guidelines

-   All modals use `hx-get` to load content into `#modal-body`, with `hx-target="#modal-body"` and `hx-swap="innerHTML"`
-   Use `hx-post` for form submission from within modals
-   Forms should include a `form-errors` block (or similar) to surface backend Pydantic validation messages
-   Live updates (keyspace/complexity) should trigger on `input` or `change` events using `hx-trigger`
-   Fragments should be reusable: e.g., `_attack_row.html`, `_attack_form.html`, `_toast.html`

### 🧠 Live Keyspace Estimation

-   For all attack editors (dictionary, brute-force, mask, previous passwords), call:
    `POST /api/v1/web/attacks/estimate`
-   Use this to show estimated password count and complexity dots
-   Trigger the estimation from form inputs (e.g., wordlist, modifiers, length, mask)

### ⚙️ Rule Modifier Buttons

-   Modifier buttons like `+ Change case`, `+ Substitute chars` should map to known rule files
-   When clicked, they should:

    -   Add a visual tag below the section
    -   Set an internal hidden field to reference a bundled rule file
    -   Ensure backend receives a `rule_list_id` tied to that resource

### 🧷 Fragments and Modal Naming

-   Fragments for modals go in `templates/fragments/attacks/` or similar
-   Modal triggers should use buttons with `hx-get` pointing to `/api/v1/web/attacks/new?type=dictionary` or similar
-   Editor modals should share a base layout (e.g., `modal_form_base.html`)

### 🧼 Example Components

-   Dot-based complexity uses a `div.inline-flex.space-x-1` with five `span.w-2.h-2.rounded-full` dots
-   Form buttons should follow Flowbite's `btn btn-primary` and `btn btn-outline` classes
-   Campaign view table rows should use `grid grid-cols-6` layout per spec

---

## 📚 Appendix: UI Guidelines and Flowbite Components

### 📝 Best Practices

-   Use idiomatic HTMX + Flowbite combinations; do not introduce SPA logic or React/Vue-style dynamic behavior
-   Prioritize click-reduction and layout clarity
-   Support real-time UX without requiring full page reloads
-   Ensure backend schema and permissions match the operations surfaced in the UI

### 🔧 Recommended Flowbite Components

**Layout**

-   Sidebar: [Sidebar component](https://flowbite.com/docs/components/sidebar/)
-   Navbar/Header: [Navbar component](https://flowbite.com/docs/components/navbar/)
-   Dark mode toggle: [Dark Theme Toggle](https://flowbite.com/docs/customize/dark-mode/)
-   Toasts: [Toast notifications](https://flowbite.com/docs/components/toast/)

**User & Agent Management**

-   Tables: [Table component](https://flowbite.com/docs/components/table/) with icons
-   Modals for user/agent edit: [Modal component](https://flowbite.com/docs/components/modal/)
-   Badges for status (locked/unlocked, online/offline): [Badge](https://flowbite.com/docs/components/badge/)
-   Toggle: [Toggle switch](https://flowbite.com/docs/forms/toggle/)

**Hashlist/Resource Upload Forms**

-   File Upload: [File input](https://flowbite.com/docs/forms/file-input/)
-   Text Input: [Text inputs](https://flowbite.com/docs/forms/input/)
-   Dropdown: [Select](https://flowbite.com/docs/forms/select/)
-   Textarea: [Textarea](https://flowbite.com/docs/forms/textarea/)

**Campaign Monitoring**

-   Accordion for expandable campaigns: [Accordion](https://flowbite.com/docs/components/accordion/)
-   Progress bar: [Progress bar](https://flowbite.com/docs/components/progress/)
-   Tooltip for attack metadata: [Tooltip](https://flowbite.com/docs/components/tooltip/)
-   Skeleton loading (optional): [Skeleton](https://flowbite.com/docs/components/skeleton/)

**Attack Editor**

-   Table for step list: [Table + Context Menu Dropdown](https://flowbite.com/docs/components/dropdown/)
-   Dot-based complexity: \[Progress dots or custom icons with Tooltip]
-   Add/Delete buttons: [Buttons + Icon buttons](https://flowbite.com/docs/components/buttons/)

---

## 🎨 Visual Theme & Mood

The CipherSwarm frontend must adopt a consistent visual identity built on the following principles:

### 🌘 Base Theme

-   Use the **Catppuccin Macchiato** color palette for all dark mode styling

    -   Implement via [`@catppuccin/tailwindcss`](https://github.com/catppuccin/tailwindcss)
    -   Set `defaultFlavor: 'macchiato'` in `tailwind.config.js`

### 🟣 Accent Color

-   Override the primary accent with `DarkViolet` (`#9400D3`)

    -   Set as `accent` in Tailwind's `theme.extend.colors`
    -   Used for: buttons, selection highlights, primary links, toggles, modals
    -   Should be applied consistently with `text-accent`, `bg-accent`, `border-accent`

### 🐝 Visual Motif

-   Hexagon grid or icons may be used subtly in backgrounds, cards, or modal overlays

    -   Should be low-contrast and non-intrusive (e.g., SVG background textures)
    -   Think "implied swarm coordination", not yellow stripes

### [x] Surface and Layout

-   Avoid pure black backgrounds (`#000`)
-   Use Catppuccin `base`, `surface0`, and `crust` as primary background layers
-   Ensure good contrast against `text`, `subtext0`, and `overlay1`

### 🔁 Integration

-   Theme must apply consistently across:

    -   Sidebar, navbar, toast, modal, and campaign views

-   All Flowbite components should inherit the theme via Tailwind utility classes
-   Do not use third-party CSS themes or runtime theming libraries except for Flowbite and Catppuccin.
