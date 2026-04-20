---
status: pending
priority: p3
issue_id: '015'
tags: [code-review, performance, scalability]
dependencies: []
---

# Move mark_related_tasks_stale Outside Transaction

## Problem Statement

`CrackSubmissionService#mark_related_tasks_stale` runs inside the crack submission transaction, executing an `update_all` across tasks joined through attacks and campaigns. During high-throughput crack submission bursts (thousands/sec from 25 GPUs), this extends transaction lock duration unnecessarily. The stale flag is a best-effort notification checked on next agent poll.

## Findings

- **Source**: performance-oracle agent
- **Evidence**: `app/services/crack_submission_service.rb:169-176`

## Proposed Solutions

### Option A: Move to after_commit callback or post-transaction block

- Execute `mark_related_tasks_stale` after the transaction commits
- **Effort**: Small
- **Risk**: Low — stale flag is advisory, not transactional

## Acceptance Criteria

- [ ] `mark_related_tasks_stale` executes outside the main transaction
- [ ] Crack submission specs still pass
- [ ] Reduced transaction lock duration under burst conditions
