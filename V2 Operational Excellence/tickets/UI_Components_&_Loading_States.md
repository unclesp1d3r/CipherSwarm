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

- [ ] Component created: app/components/agent_status_card_component.rb
- [ ] Template created: app/components/agent_status_card_component.html.erb
- [ ] Displays: status badge, agent name, hash rate, error indicator
- [ ] Uses existing StatusPillComponent for status badge
- [ ] Error indicator shows count if > 0 errors in last 24h
- [ ] Card links to agent detail page

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

## Estimated Effort

**2-3 days** (8 components + 2 Stimulus controllers + templates + tests)
