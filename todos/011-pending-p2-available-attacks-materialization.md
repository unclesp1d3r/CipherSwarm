---
status: pending
priority: p2
issue_id: '011'
tags: [code-review, performance, scalability]
dependencies: []
---

# Remove .to_a Materialization from available_attacks

## Problem Statement

`TaskAssignmentService#find_task_from_available_attacks` calls `available_attacks.to_a`, materializing all available attacks plus eager-loaded campaigns, hash_lists, and projects into memory. Since the method returns on the first assignable match, this loads the entire set unnecessarily.

## Findings

- **Source**: performance-oracle agent
- **Evidence**: `app/services/task_assignment_service.rb:240`
- **Impact**: Memory bloat proportional to number of queued attacks

## Proposed Solutions

### Option A: Use find_each with early return (Recommended)

- Replace `.to_a` with `.find_each` and return on first match
- **Effort**: Small
- **Risk**: Low

## Acceptance Criteria

- [ ] No `.to_a` on available_attacks query
- [ ] Task assignment specs still pass
