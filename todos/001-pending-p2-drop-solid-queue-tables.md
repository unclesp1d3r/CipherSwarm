---
status: pending
priority: p2
issue_id: '001'
tags: [code-review, architecture, database, cleanup]
dependencies: []
---

# Drop Solid Queue Tables

## Problem Statement

Eight `solid_queue_*` tables remain in the schema (blocked_executions, claimed_executions, failed_executions, jobs, pauses, processes, ready_executions, scheduled_executions, semaphores) while Sidekiq is the active job backend. These are dead weight from a migration or exploration that was abandoned. They confuse contributors, add migration complexity, and could mask configuration errors if Rails auto-discovers the Solid Queue adapter.

## Findings

- **Source**: architecture-strategist agent, schema review
- **Evidence**: `db/schema.rb` lines 410-501 contain 8 `solid_queue_*` tables
- **Impact**: Contributor confusion, unnecessary schema bloat, potential adapter misconfiguration

## Proposed Solutions

### Option A: Migration to drop all tables (Recommended)

- **Pros**: Clean schema, no ambiguity, small migration
- **Cons**: Irreversible (but data is unused)
- **Effort**: Small
- **Risk**: Low — tables contain no production data

### Option B: Leave and document

- **Pros**: Zero risk
- **Cons**: Debt persists, confusion continues
- **Effort**: Trivial
- **Risk**: None

## Recommended Action

_To be filled during triage_

## Technical Details

- **Affected files**: `db/schema.rb`, new migration file
- **Tables**: `solid_queue_blocked_executions`, `solid_queue_claimed_executions`, `solid_queue_failed_executions`, `solid_queue_jobs`, `solid_queue_pauses`, `solid_queue_processes`, `solid_queue_ready_executions`, `solid_queue_recurring_executions`, `solid_queue_recurring_tasks`, `solid_queue_scheduled_executions`, `solid_queue_semaphores`
- **Command**: `just generate migration DropSolidQueueTables`

## Acceptance Criteria

- [ ] All `solid_queue_*` tables removed from schema
- [ ] No Solid Queue references in initializers or config
- [ ] Migration is reversible (recreate tables in `down`)
- [ ] `just ci-check` passes

## Work Log

| Date       | Action                           | Learnings                    |
| ---------- | -------------------------------- | ---------------------------- |
| 2026-04-01 | Created from architecture review | Found during schema analysis |

## Resources

- PR #830 architecture review
- `db/schema.rb` lines 410-501
