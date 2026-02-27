# UI Components & Loading States

## Overview

Implement reusable UI components and loading state patterns for consistent user experience across the application. This ticket creates the foundational UI building blocks used by other tickets.

## Scope

**Included:**

- ViewComponents for all new UI patterns
- Stimulus controllers for interactivity (tabs, toasts)
- Skeleton loader components for loading states
- Toast notification system
- Component templates (ERB files)
- Component tests

**Excluded:**

- Integration with specific pages (handled by feature tickets)
- Existing components (StatusPill, ProgressBar already exist)

## Acceptance Criteria

### ViewComponents

**AgentStatusCardComponent:**

- [x] Component created: app/components/agent_status_card_component.rb
- [x] Template created: app/components/agent_status_card_component.html.erb
- [x] Displays: status badge, agent name, hash rate, error indicator
- [x] Uses existing StatusPillComponent for status badge
- [x] Error indicator shows count if > 0 errors in last 24h
- [x] Card links to agent detail page
- [x] Component delegates to Turbo Stream broadcast partials for real-time updates
- [x] Individual card sections update without full-page refresh
- [x] State, last seen, hash rate, and errors broadcast independently
- [x] Broadcast partials are minimal and don't reference current_user
- [x] Stable DOM IDs enable targeted replacement
- [x] `error_count_last_24h` method removed from component class, moved to partial logic

**Agent Index Partials:**

Four targeted partials handle independent Turbo Stream broadcasts for agent index cards:

- [x] `_index_state.html.erb` - Displays agent state badge with color coding (online/offline/error). Uses `StatusPillComponent` and has a stable DOM ID using `dom_id(agent, :index_state)` pattern.
- [x] `_index_last_seen.html.erb` - Shows relative time since last heartbeat ("X minutes ago" or "Not seen yet"). DOM ID: `dom_id(agent, :index_last_seen)`.
- [x] `_index_hash_rate.html.erb` - Displays current hash rate or "N/A" fallback. DOM ID: `dom_id(agent, :index_hash_rate)`.
- [x] `_index_errors.html.erb` - Shows error count badge for last 24 hours (excluding info severity). Entire `<div>` has DOM ID: `dom_id(agent, :index_errors)`. Text turns red when error count > 0.

Each partial:

- Has a stable DOM ID for targeted replacement
- Is broadcast via `broadcast_replace_later_to` callback (runs in background job)
- Runs WITHOUT access to `current_user` or session (background job context)
- Contains only the minimum HTML needed for that specific UI element

**Broadcast Callbacks:**

Agent model callbacks trigger targeted broadcasts:

```ruby
after_update_commit :broadcast_index_state, if: -> { saved_change_to_state? }
after_update_commit :broadcast_index_last_seen, if: -> { saved_change_to_last_seen_at? }
```

AgentError model callback:

```ruby
after_create_commit :broadcast_index_errors
```

HashcatStatus updates trigger hash rate broadcasts via `update_agent_metrics` method (uses `update_columns` to bypass callbacks, then manually broadcasts).

**AgentDetailTabsComponent:**

- [ ] Component created: app/components/agent_detail_tabs_component.rb
- [ ] Template created: app/components/agent_detail_tabs_component.html.erb
- [ ] Renders slots: overview_tab, errors_tab, configuration_tab, capabilities_tab
- [ ] Integrates with Stimulus tabs controller
- [ ] Preserves tab structure for Turbo Stream broadcasts

**CampaignProgressComponent:**

- [ ] Component created: app/components/campaign_progress_component.rb
- [ ] Template created: app/components/campaign_progress_component.html.erb
- [ ] Displays: progress bar, percentage text, ETA text
- [ ] Uses existing ProgressBarComponent or extends it
- [ ] Handles missing ETA gracefully ("Calculating...")

**ErrorModalComponent:**

- [ ] Component created: app/components/error_modal_component.rb
- [ ] Template created: app/components/error_modal_component.html.erb
- [ ] Displays: error message, severity badge, timestamp
- [ ] Uses Bootstrap modal component
- [ ] Severity badges: fatal/error (danger), warning (warning), info (info)

**SystemHealthCardComponent:**

- [ ] Component created: app/components/system_health_card_component.rb
- [ ] Template created: app/components/system_health_card_component.html.erb
- [ ] Displays: service name, status badge, latency, error message
- [ ] Status variants: healthy (success), unhealthy (danger), checking (secondary)
- [ ] Icons: check-circle (healthy), x-circle (unhealthy)

**TaskActionsComponent:**

- [ ] Component created: app/components/task_actions_component.rb
- [ ] Template created: app/components/task_actions_component.html.erb
- [ ] Conditional buttons: cancel, retry, reassign, view logs, download results
- [ ] Buttons shown based on task state and user permissions
- [ ] Uses Railsboot button components

**SkeletonLoaderComponent:**

- [ ] Component created: app/components/skeleton_loader_component.rb
- [ ] Template created: app/components/skeleton_loader_component.html.erb
- [ ] Types supported: :agent_list, :campaign_list, :health_dashboard
- [ ] Configurable count (default: 5)
- [ ] Uses CSS animations for shimmer effect
- [ ] Matches layout of actual content

**ToastNotificationComponent:**

- [ ] Component created: app/components/toast_notification_component.rb
- [ ] Template created: app/components/toast_notification_component.html.erb
- [ ] Variants: success, danger, warning, info
- [ ] Integrates with Stimulus toast controller
- [ ] Auto-dismiss after 5 seconds
- [ ] Positioned in top-right corner

### Stimulus Controllers

**tabs_controller.js:**

- [ ] Controller created: app/javascript/controllers/tabs_controller.js
- [ ] Targets: tab, panel
- [ ] Action: switch(event) - switches active tab
- [ ] Shows first tab by default on connect
- [ ] Updates active tab styling
- [ ] Hides/shows panels with d-none class

**toast_controller.js:**

- [ ] Controller created: app/javascript/controllers/toast_controller.js
- [ ] Values: autohide (boolean, default: true), delay (number, default: 5000)
- [ ] Initializes Bootstrap Toast on connect
- [ ] Auto-dismiss after delay
- [ ] Removes element from DOM after hidden
- [ ] Imports Bootstrap Toast component

### Shared Partials

- [ ] Toast partial created: app/views/shared/\_toast.html.erb
- [ ] Toast container added to layout: file:app/views/layouts/application.html.erb
- [ ] Container positioned for toast display (top-right)

### Testing

- [ ] Component tests for all ViewComponents
- [ ] Stimulus controller tests for tabs_controller
- [ ] Stimulus controller tests for toast_controller
- [ ] Visual regression tests (optional, if using tools)
- [ ] Verify components work in air-gapped environment (no external assets)

## Technical References

- **Core Flows**: spec:50650885-e043-4e99-960b-672342fc4139/c565e255-83e7-4d16-a4ec-d45011fa5cad (Flow 6: Loading & Feedback Patterns)
- **Tech Plan**: spec:50650885-e043-4e99-960b-672342fc4139/f3c30678-d7af-45ab-a95b-0d0714906b9e (Component Architecture, Stimulus Controllers)
- **Turbo Stream Broadcasts**: doc:GOTCHAS.md (section "Turbo Stream Broadcasts")
- **Agent Monitoring**: ticket:50650885-e043-4e99-960b-672342fc4139/[Agent Monitoring & Real-Time Updates]

## Dependencies

**Requires:**

- None (foundational ticket)

**Blocks:**

- ticket:50650885-e043-4e99-960b-672342fc4139/[Agent Monitoring & Real-Time Updates] - Provides AgentStatusCardComponent, tabs controller
- ticket:50650885-e043-4e99-960b-672342fc4139/[Campaign Progress & ETA Display] - Provides CampaignProgressComponent, ErrorModalComponent
- ticket:50650885-e043-4e99-960b-672342fc4139/[Task Management Actions] - Provides TaskActionsComponent
- ticket:50650885-e043-4e99-960b-672342fc4139/[System Health Monitoring] - Provides SystemHealthCardComponent

## Implementation Notes

- Follow existing ViewComponent patterns in file:app/components/
- Use `dry-initializer` option syntax (already used in existing components)
- Inherit from `ApplicationViewComponent`
- Use Railsboot components for layout/structure where possible
- Test components in isolation before integrating
- Ensure all assets (CSS, JS) are bundled for air-gapped deployment
- Use Bootstrap 5 components (already in stack)

**Turbo Stream Broadcast Pattern:**

The AgentStatusCardComponent demonstrates a reusable pattern for real-time component updates:

1. **Extract Minimal Partials** - Create small partials (`_index_state.html.erb`, `_index_hash_rate.html.erb`) that wrap a single UI element with a stable DOM ID using `dom_id(record, :suffix)`.

2. **Model Callbacks** - Use conditional `after_update_commit` callbacks (e.g., `if: -> { saved_change_to_state? }`) to broadcast only when specific attributes change, reducing unnecessary updates.

3. **Background Job Context** - Broadcast partials run in background jobs WITHOUT access to `current_user` or session. All data must come from the model or explicit locals.

4. **Targeted Replacement** - Use `broadcast_replace_later_to` with the stable DOM ID as the target to update individual sections without full-page refresh.

This pattern extends to other real-time components. See the Attack model's `broadcast_index_state` implementation for a similar approach. For constraints and gotchas, reference doc:GOTCHAS.md section "Turbo Stream Broadcasts".

## Estimated Effort

**2-3 days** (8 components + 2 Stimulus controllers + templates + tests)
