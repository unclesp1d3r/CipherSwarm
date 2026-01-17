# Agent Monitoring & Real-Time Updates

## Overview

Implement comprehensive agent monitoring with real-time status updates, performance metrics, and error visibility. This ticket delivers the agent fleet monitoring flow from spec:50650885-e043-4e99-960b-672342fc4139/c565e255-83e7-4d16-a4ec-d45011fa5cad.

## Scope

**Included:**

- Agent list view with status badges, hash rate, error indicators
- Agent detail page with tabbed interface (Overview, Errors, Configuration, Capabilities)
- Targeted Turbo Stream broadcasts for agent status updates
- AgentStatusCardComponent for list view
- AgentDetailTabsComponent for detail view
- Stimulus tabs controller for tab switching
- Real-time updates via scoped Turbo Streams

**Excluded:**

- Agent creation/editing forms (already exist)
- Agent API endpoints (already exist)
- Agent benchmarking (already exists)

## Acceptance Criteria

### Agent List View

- [ ] Agent list displays cards (not table) with:

  - Status badge (active/offline/pending with color coding)
  - Agent name (custom_label or host_name)
  - Hash rate (formatted: "—", "0 H/s", or "X.X MH/s")
  - Error indicator (red badge with count if errors in last 24h)
  - Link to agent detail page

- [ ] Agent list uses grid layout (3-4 cards per row)

- [ ] Empty state shown when no agents exist

- [ ] Skeleton loader shown while loading

- [ ] Real-time updates via Turbo Streams (individual cards update)

### Agent Detail Page - Tabbed Interface

**Tab Structure:**

- [ ] Four tabs: Overview, Errors, Configuration, Capabilities
- [ ] Tabs implemented with Stimulus controller (fast switching, no network requests)
- [ ] First tab (Overview) shown by default
- [ ] Tab content loaded upfront (all tabs rendered, hidden with CSS)

**Overview Tab:**

- [ ] Current task (with link to task detail page)
- [ ] Performance metrics (hash rate, temperature, utilization)
- [ ] Agent state and last seen timestamp
- [ ] Operating system and client signature
- [ ] Projects assigned

**Errors Tab:**

- [ ] Recent errors table (last 100 errors)
- [ ] Columns: Timestamp, Severity, Message
- [ ] Severity badges (fatal/error/warning/info with color coding)
- [ ] Pagination if > 50 errors
- [ ] Empty state if no errors

**Configuration Tab:**

- [ ] Advanced configuration display (agent_update_interval, use_native_hashcat, backend_device)
- [ ] Enabled/disabled status
- [ ] User assignment
- [ ] Edit button (links to existing edit form)

**Capabilities Tab:**

- [ ] Supported hash types (from benchmarks)
- [ ] Benchmark data (hash type, speed)
- [ ] Device information
- [ ] Last benchmark date

### Real-Time Updates

- [ ] Agent status broadcasts target individual cards in list view
- [ ] Agent detail broadcasts target tab content only (preserve tab structure)
- [ ] Broadcasts don't reset active tab
- [ ] Broadcasts don't disrupt user interaction
- [ ] Broadcast errors logged but don't break functionality

### Components

- [ ] `AgentStatusCardComponent` created with status badge, hash rate, error count
- [ ] `AgentDetailTabsComponent` created with slot rendering for tabs
- [ ] Components follow existing Railsboot patterns
- [ ] Components tested with component specs

### Testing

- [ ] System test: View agent list, verify real-time updates
- [ ] System test: Navigate agent detail tabs, verify content
- [ ] System test: Verify broadcasts update correct elements
- [ ] Component tests for AgentStatusCardComponent
- [ ] Component tests for AgentDetailTabsComponent

## Technical References

- **Core Flows**: spec:50650885-e043-4e99-960b-672342fc4139/c565e255-83e7-4d16-a4ec-d45011fa5cad (Flow 1: Agent Fleet Monitoring)
- **Tech Plan**: spec:50650885-e043-4e99-960b-672342fc4139/f3c30678-d7af-45ab-a95b-0d0714906b9e (Component Architecture, Turbo Stream Broadcasts)

## Dependencies

**Requires:**

- ticket:50650885-e043-4e99-960b-672342fc4139/[Database Schema & Model Extensions] - Needs cached metrics columns
- ticket:50650885-e043-4e99-960b-672342fc4139/[UI Components & Loading States] - Needs Stimulus tabs controller

**Blocks:**

- None (other features can be implemented in parallel)

## Implementation Notes

- Replace existing file:app/views/agents/index.html.erb with card-based layout
- Refactor existing file:app/views/agents/show.html.erb to use tabbed interface
- Use `dom_id` helper for consistent broadcast targets
- Test Turbo Stream broadcasts don't interfere with Stimulus controller
- Ensure broadcasts work in air-gapped environment (no external dependencies)

## Estimated Effort

**2-3 days** (views + components + Turbo Streams + tests)
