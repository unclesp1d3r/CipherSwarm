---
status: pending
priority: p2
issue_id: '013'
tags: [code-review, performance, rails, scalability]
dependencies: []
---

# Remove hashcat_statuses Eager Load from campaigns#show

## Problem Statement

`campaigns#show` eager-loads ALL hashcat_statuses for ALL tasks: `@campaign.attacks.by_complexity.includes(tasks: :hashcat_statuses)`. A campaign with 10 attacks, 10 tasks each, and 50 statuses per task loads 5,000+ HashcatStatus records plus DeviceStatus children. The view likely only needs `cached_progress_pct` from the task, not the full status history.

## Findings

- **Source**: performance-oracle agent
- **Evidence**: `app/controllers/campaigns_controller.rb:34`
- **Impact**: Multi-second page loads for active campaigns

## Proposed Solutions

### Option A: Remove hashcat_statuses from includes (Recommended)

- Change to `.includes(:tasks)` and ensure views use `task.cached_progress_pct`
- **Effort**: Small
- **Risk**: Medium — need to verify no view template accesses statuses directly

## Acceptance Criteria

- [ ] No eager load of hashcat_statuses on campaigns#show
- [ ] Campaign page renders correctly using cached progress
- [ ] Page load time improved for active campaigns
