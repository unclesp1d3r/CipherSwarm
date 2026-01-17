# Campaign Progress & ETA Display

## Overview

Implement campaign progress monitoring with accurate ETAs, error visibility, and recent crack results. This ticket delivers the campaign progress monitoring flow from spec:50650885-e043-4e99-960b-672342fc4139/c565e255-83e7-4d16-a4ec-d45011fa5cad.

## Scope

**Included:**

- Campaign detail page enhancements (progress bars, ETAs, error modals)
- Attack progress component with percentage and ETA
- Campaign ETA summary (current + total)
- Recent cracks expandable section
- Error modal for attack failures
- Error log section for campaign errors
- Targeted Turbo Stream broadcasts for attack progress
- CampaignProgressComponent
- ErrorModalComponent

**Excluded:**

- Campaign creation/editing (already exists, separate flow)
- Attack creation/editing (already exists)
- Hash list management (already exists)

## Acceptance Criteria

### Campaign Detail Page

**ETA Summary:**

- [ ] Alert box at top showing:
  - Current Attack ETA (time remaining for running attacks)
  - Total Campaign ETA (estimated completion time for all attacks)
- [ ] ETAs formatted as human-readable time ("2 hours", "30 minutes")
- [ ] ETAs update in real-time via Turbo Streams
- [ ] "Calculating..." shown if ETA unavailable

**Attack Progress:**

- [ ] Each attack in stepper shows:

  - Progress bar (0-100%)
  - Percentage text ("45% complete")
  - ETA text ("ETA: 2h 30m")
  - Status badge (pending/running/completed/failed)
  - Error indicator (⚠️) if attack failed

- [ ] Progress bars update in real-time via Turbo Streams

- [ ] Progress bars use existing ProgressBarComponent or new CampaignProgressComponent

**Error Handling:**

- [ ] Clicking error indicator (⚠️) opens modal with error details
- [ ] Error modal shows: error message, timestamp, severity, affected task
- [ ] Error modal has "Close" button
- [ ] Error log section at bottom shows all campaign errors (chronological)
- [ ] Error log paginated if > 50 errors

**Recent Cracks:**

- [ ] Button shows "View Recent Cracks (X)" where X is count from last 24h
- [ ] Clicking button expands collapsible section
- [ ] Section shows table with: Hash (truncated), Plaintext, Cracked At
- [ ] Table limited to 100 most recent cracks
- [ ] Empty state if no cracks in last 24h
- [ ] Plaintexts always visible (not masked)

### Real-Time Updates

- [ ] Attack progress bars update when task status changes
- [ ] Campaign ETA updates when attacks complete or progress
- [ ] Recent cracks count updates when hashes are cracked
- [ ] Broadcasts target individual attack progress divs (not entire page)
- [ ] Broadcasts don't disrupt user interaction (scrolling, clicking)

### Components

- [ ] `CampaignProgressComponent` created with progress bar and ETA display
- [ ] `ErrorModalComponent` created with severity badge and error details
- [ ] Components follow existing Railsboot patterns
- [ ] Components tested with component specs

### Testing

- [ ] System test: View campaign, verify progress bars and ETAs
- [ ] System test: Click error indicator, verify modal opens
- [ ] System test: Expand recent cracks, verify table displays
- [ ] System test: Verify real-time progress updates
- [ ] Component tests for CampaignProgressComponent
- [ ] Component tests for ErrorModalComponent

## Technical References

- **Core Flows**: spec:50650885-e043-4e99-960b-672342fc4139/c565e255-83e7-4d16-a4ec-d45011fa5cad (Flow 2: Campaign Progress Monitoring)
- **Tech Plan**: spec:50650885-e043-4e99-960b-672342fc4139/f3c30678-d7af-45ab-a95b-0d0714906b9e (Campaign Model ETA, Component Architecture)

## Dependencies

**Requires:**

- ticket:50650885-e043-4e99-960b-672342fc4139/[Database Schema & Model Extensions] - Needs Campaign ETA methods, HashList recent_cracks
- ticket:50650885-e043-4e99-960b-672342fc4139/[UI Components & Loading States] - Needs ErrorModalComponent

**Blocks:**

- None (other features can be implemented in parallel)

## Implementation Notes

- Enhance existing file:app/views/campaigns/show.html.erb (don't replace entirely)
- Use existing file:app/views/campaigns/\_attack_stepper_line.html.erb as base, enhance with progress
- Bootstrap collapse component for recent cracks (no custom JavaScript needed)
- Bootstrap modal component for error display
- Test with campaigns that have multiple attacks in different states
- Verify real-time updates work in air-gapped environment

## Estimated Effort

**2-3 days** (campaign view enhancements + components + Turbo Streams + tests)
