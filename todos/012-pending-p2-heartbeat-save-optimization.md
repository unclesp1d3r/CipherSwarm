---
status: pending
priority: p2
issue_id: '012'
tags: [code-review, performance, api]
dependencies: []
---

# Optimize Heartbeat Activity Writes

## Problem Statement

The heartbeat endpoint calls `@agent.save` when `params[:activity]` is present, triggering full model validations (uniqueness checks for token, custom_label, etc.) and callbacks. With 10+ agents at 30s intervals, that's 20+ full saves/minute on the hottest API endpoint. Combined with `update_last_seen` and the state machine `heartbeat` event, a single request can trigger 2-3 DB writes.

## Findings

- **Source**: performance-oracle agent
- **Evidence**: `app/controllers/api/v1/client/agents_controller.rb:38-97`
- **Impact**: Unnecessary validation overhead on every heartbeat

## Proposed Solutions

### Option A: Use update_columns for activity (Recommended)

- Replace `@agent.save` with `@agent.update_columns(current_activity: params[:activity])`
- Bypasses validations (activity is a trusted agent-provided string)
- **Effort**: Small
- **Risk**: Low — activity field has no complex validation

## Acceptance Criteria

- [ ] Heartbeat with activity change uses `update_columns`
- [ ] No full model validation on heartbeat
- [ ] Agent heartbeat specs still pass
