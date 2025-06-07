# CipherSwarm v2 Dashboard UX Design

_Last updated: 2025-05-27_

## 🎯 Purpose

The CipherSwarm v2 Dashboard is the landing view for authenticated users and the operational command center for real-time campaign oversight. It prioritizes clarity, quick insight, and control access according to role. This is not a traditional analytics dashboard but a tactical interface focused on live campaigns, attacks, and agents.

## 🧱 Layout Overview

The Dashboard UI follows a classic sidebar + header layout with a responsive, dark-mode-friendly design.

### Base Layout (SvelteKit + Shadcn-Svelte)

* **Sidebar (collapsible):**

  * Logo
  * Navigation links: Dashboard, Campaigns, Attacks, Agents, Resources, Users (admin only), Settings
  * Active item indicator

* **Header:**

  * Project selector (if more than one project is assigned)
  * User avatar + dropdown menu (profile, logout)
  * Live status indicators (SSE connection, backend status)

* **Main Content Area:**

  * Top strip with operational status **cards** arranged in a responsive row layout. Each card summarizes a critical system metric and uses a compact, visually scannable format. All cards should update reactively using SSE data, with no need for manual refresh.

    * **Active Agents** — Displays the number of online agents out of the total registered. Clicking this card opens the **Agent Status Sheet**, which provides a detailed overview of each agent. The card should include a short label (e.g., “Online / Total”), a numeric highlight, and optional icon.
    * **Running Tasks** — Reflects the number of active campaigns, showing the total and a percentage breakdown of running vs completed tasks. This metric gives a sense of overall system activity.
    * **Recently Cracked Hashes** — Counts the number of hashes cracked in the last 24 hours, scoped to the user’s accessible projects. Should include a link to view all results.
    * **Resource Usage** — Shows a lightweight visual (e.g., sparkline or mini line chart) of aggregate hash rate (hashes per second) across all agents over the last 8 hours. Data comes from `get_agent_device_performance_timeseries()`.

Each card should follow the semantic layout patterns of Shadcn-Svelte components (`Card`, `CardHeader`, `CardTitle`, `CardContent`, etc.) and rely on Tailwind classes for spacing and responsiveness. Avoid over-styling; favor clarity and alignment with Shadcn design principles.

* Primary content: **Campaign Overview List**

### 🟦 Empty State Guidance

If no campaigns or agents are active, the dashboard should display a friendly empty state with guidance (e.g., “No active campaigns yet. Join or create one to begin.”)

## 📈 Campaign Overview Section

The campaign list is the core of the dashboard. It presents **all campaigns across the system**, not limited by project. Campaigns marked as sensitive will display a generic label (e.g., "Sensitive Campaign") unless the current user has access. All users can see campaign status, progress, and agent activity to understand system load, but only users with permission can expand a campaign to view its attacks or details. This provides global operational awareness while preserving data confidentiality.

### Campaign Row Design

Campaigns should be sorted by default with **Running** campaigns first, followed by most recently updated. This ensures active work stays in focus. Campaigns with failed attacks should show a red badge or error icon inline, even if other attacks are still running.

Each campaign appears as a row in an accordion-like component:

* **Visible on collapsed row:**

  * Campaign name
  * Progress bar (keyspace-weighted, live updates)
  * State — represented by a compact badge or icon with color coding (Running = purple, Completed = green, Error = red, Paused = gray)
  * Summary with compact state badge (e.g., ⚡ 3 attacks / 1 running / ETA 3h), where the icon or colored badge conveys the overall state (Running = purple, Completed = green, Error = red, Paused = gray)
  * Expand button/icon

* **Visible when expanded:**

  * List of attack rows with:

    * Attack type, short config summary
    * Progress bar
    * Estimated time to completion
    * Gear icon for options (edit, rerun, delete)
  * Attached agent count and status
  * Toggle or link to full campaign view

### Style/Components

* Shadcn-Svelte Accordion
* Progress bars with dynamic color by state
* Tooltip on hover for full config summary
* Responsive layout for smaller screens (campaigns stack vertically)

## 🔔 Live Toast Notifications

Toast notifications show whenever a hash is cracked in a campaign visible to the current user. If multiple hashes are cracked in a short period, the UI should group them into a batch toast (e.g., “5 new hashes cracked”) with a link to the hashlist view:

* Must be rate-limited (batch updates if needed)
* Contains plaintext, attack used, hashlist name, timestamp
* Uses Shadcn-Svelte Toast component
* Option to view full hashlist page or suppress future toasts

## 🖥️ Agent Status Overview

Agent status is accessible via a slide-out **Sheet** anchored to the right side of the dashboard. The Sheet is triggered by clicking the **Active Agents** card in the top strip.

Each agent is displayed as a vertically stacked **Card** inside the Sheet:

* **Header:** Agent label or ID with status badge (🟢 Online, 🟡 Idle, 🔴 Offline)
* **Subtext:** Last seen timestamp (e.g., "Seen 1m ago")
* **Current Task:** Display current Campaign / Attack name or `Idle`
* **Guess Rate:** Current or averaged hashes per second, bolded
* **Sparkline:** Guess rate trend over the last 8 hours (SVG or chart library)
* **Expand button (admin-only):** Opens Agent Detail page or modal with configuration info, device list, and management tools

The Sheet is full-height and fixed-width with a scrollable vertical layout. It is not mobile-optimized. This approach allows a scalable, glanceable agent view without cluttering the main dashboard.

Example layout for each agent card:

```
╔════════════════════════════════╗
║ Agent Name or Label            ║
║ ● Online   |  🕒 Last seen 1m  ║
╠════════════════════════════════╣
║ 📊 Current Task: Campaign X    ║
║ 🔢 Guess Rate: 55 MH/s         ║
║ 📈 Sparkline: ▄▅▆▇█▇▆▅▃        ║
╚════════════════════════════════╝
```

This is purely illustrative and should be translated into a real Shadcn-Svelte Card component with dynamic values and styling.

All logged-in users can view basic agent status (e.g., online/offline, current task, performance) across the entire system. However, access to detailed configuration — including hardware setup, device toggles, and update intervals — is limited to admins only. Only admins may modify agents or view sensitive configuration data.

## 🔧 Actionable Insights / UI

If there are paused or failed attacks, show a banner strip at the top with:

* Number of affected campaigns
* “Resume All” button if user has permission
* “View Details” opens modal with campaign links

## 🧪 Technical Notes

* All status data must update via SSE.
* If SSE is unavailable, fallback to JSON polling on timers.
* Show stale data indicators if last update >30 seconds.
* Must work offline for development (mock SSE stream).

## 🧰 Component Inventory (Shadcn-Svelte)

* Layout: `Sidebar`, `Header`, `Accordion`, `Toast`, `Progress`, `Tooltip`, `Dialog`
* Typography: `Heading`, `Text`, `Badge`
* UI logic: Svelte stores for session + SSE, role-aware nav

## 🎨 Design Philosophy

The dashboard is a real-time operational overview — it prioritizes clarity, system awareness, and fast visual parsing. It is not an analytics page, a settings page, or an editing surface.

### Core Intent:

* Show **live system health** without requiring clicks
* Make **important activity and problems** easy to spot
* Avoid clutter — present only **current**, **actionable**, and **relevant** information
* **Defer deep interaction** (edits, config, history views) to dedicated detail pages

This aligns with CipherSwarm v2's broader mission to evolve from "a tool" into "a platform" — shifting toward guided workflows, real-time observability, and a smarter cracking interface.

## 📐 Layout Grid and Visual Rhythm

* Uses a **12-column grid** for layout consistency
* Apply vertical spacing (`gap-y-4`, `space-y-6`) between components
* Top strip cards: uniform height, consistent padding, horizontally aligned
* Campaign and agent rows: use grid layout to support alignment and readability

## 🧠 State Management Notes

* All live data (campaigns, agents, cracked hashes) is streamed via SSE
* Frontend should use Svelte stores to manage reactive state
* A mock stream should simulate system activity in development mode for offline support

## 🎨 Status Color Reference

| State     | Color  | Icon Variant |
| --------- | ------ | ------------ |
| Running   | Purple | ⚡ or ⏱️      |
| Completed | Green  | ✅ or ✔️      |
| Error     | Red    | ❌ or 🛑      |
| Paused    | Gray   | ⏸️ or 🏁     |
| Offline   | Muted  | 🔘 or 📴     |

## 🔐 Access Behavior

* The dashboard aggregates data from all campaigns across all projects.
* Campaigns marked as sensitive are anonymized unless the user has explicit access.
* Users see progress and operational metrics even for campaigns they cannot interact with.
* Hash lists are considered highly sensitive and are strictly **project-scoped**. Users only see hash lists from their assigned projects, and the UI reinforces scoping to avoid accidental crossover or leakage.
* Role-based control governs interactivity:

  * Admins: see all campaigns, agents, and config tools
  * Users: see only assigned campaigns + agents
