---
status: pending
priority: p1
issue_id: '009'
tags: [code-review, performance, correctness, rails]
dependencies: []
---

# Fix uncracked_count Cache Staleness During Crack Submissions

## Problem Statement

`HashList#uncracked_count` uses `cache_key_with_version` (based on `updated_at`), but `CrackSubmissionService#process_crack` updates hash_items via `update_all` (bypassing AR callbacks) and only touches `campaign`, not `hash_list`. The hash_list's `updated_at` never changes, so the cached count stays stale. This can prevent task completion when `attack.hash_list.uncracked_count.zero?` returns a stale positive count.

## Findings

- **Source**: performance-oracle agent
- **Evidence**: `app/models/hash_list.rb:157-161`, `app/services/crack_submission_service.rb:113-118,180`
- **Impact**: Incorrect state machine transitions — tasks may not complete even when all hashes are cracked

## Proposed Solutions

### Option A: Touch hash_list in CrackSubmissionService (Recommended)

- Add `task.attack.campaign.hash_list.touch` after `update_all`
- **Pros**: Minimal change, fixes cache invalidation
- **Cons**: Extra DB write per crack submission
- **Effort**: Small
- **Risk**: Low

### Option B: Bypass cache in process_crack

- Call `hash_list.hash_items.uncracked.count` directly instead of cached version
- **Pros**: Always accurate
- **Cons**: No caching benefit in the hot path
- **Effort**: Small
- **Risk**: Low

## Acceptance Criteria

- [ ] `uncracked_count` reflects actual count after crack submission
- [ ] State machine transitions correctly when all hashes cracked
- [ ] `just ci-check` passes
