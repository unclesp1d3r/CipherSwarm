---
status: pending
priority: p2
issue_id: '002'
tags: [code-review, performance, architecture, scalability]
dependencies: []
---

# Push TaskPreemptionService Filtering to SQL

## Problem Statement

`TaskPreemptionService#find_preemptable_task` loads all running tasks from lower-priority campaigns into Ruby memory, filters with `.select`, then sorts with `min_by`. With many concurrent tasks across projects, this materializes the entire candidate set including eager-loaded `hashcat_statuses`. The `preemptable?` check on each task may trigger additional queries if `cached_progress_pct` is nil.

At 10x scale (100+ agents, dozens of concurrent tasks), this becomes a memory and latency bottleneck.

## Findings

- **Source**: architecture-strategist agent, scalability analysis
- **Evidence**: `app/services/task_preemption_service.rb` lines 93-136
- **Impact**: Memory bloat and latency under high concurrency

## Proposed Solutions

### Option A: SQL CTE with LIMIT 1 (Recommended)

- Push preemption_count, progress filtering, and priority ordering into a single SQL query
- Use a CTE or subquery to find the single best candidate
- **Pros**: O(1) memory, single DB round trip, leverages existing indexes
- **Cons**: More complex SQL, harder to test edge cases
- **Effort**: Medium
- **Risk**: Medium — must preserve the tiebreaker logic (task.id for determinism)

### Option B: Batch with cursor

- Use `find_each` with batch size to avoid loading all candidates at once
- Still filter in Ruby but process in chunks
- **Pros**: Simpler change, reduces peak memory
- **Cons**: Still N queries for `preemptable?` checks, slower than pure SQL
- **Effort**: Small
- **Risk**: Low

### Option C: Materialized view for preemption candidates

- Create a DB view that pre-computes preemptable tasks
- **Pros**: Fast reads, clean interface
- **Cons**: Staleness, maintenance overhead, over-engineering
- **Effort**: Large
- **Risk**: High — adds infrastructure complexity

## Recommended Action

_To be filled during triage_

## Technical Details

- **Affected files**: `app/services/task_preemption_service.rb`
- **Key method**: `find_preemptable_task` (lines 93-136)
- **Related indexes**: `(attack_id, state)`, `(agent_id, state)`
- **Tiebreaker**: `task.id` for deterministic selection (GOTCHAS.md)

## Acceptance Criteria

- [ ] `find_preemptable_task` uses SQL-level filtering with LIMIT
- [ ] No full candidate set loaded into Ruby memory
- [ ] Tiebreaker preserved (deterministic task selection)
- [ ] Existing preemption specs pass without modification
- [ ] `just ci-check` passes

## Work Log

| Date       | Action                           | Learnings                         |
| ---------- | -------------------------------- | --------------------------------- |
| 2026-04-01 | Created from architecture review | Found during scalability analysis |

## Resources

- PR #830 architecture review
- `app/services/task_preemption_service.rb`
- GOTCHAS.md (tiebreaker patterns)
