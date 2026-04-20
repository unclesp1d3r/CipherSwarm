---
status: complete
priority: p2
issue_id: '019'
tags: [code-review, soft-delete, turbo, broadcasting]
dependencies: []
origin_issue: '558'
triaged: 2026-04-19
---

# `after_commit on: [:update]` Broadcasts Fire on Soft-Delete (discard is an UPDATE)

## Problem Statement

`discard` sets `deleted_at` via an `UPDATE` statement. `Campaign` and `Attack` both have `after_commit ..., on: [:update]` broadcasters (Turbo Stream progress updates, ETA broadcasts, attack-completion checks). After the migration to `discard`, soft-deleting a record fires those update broadcasts — potentially pushing updates for a record that's about to vanish from the default query scope and the UI.

## Findings

- **Source**: ce:review run `20260419-191817-0c8476b9` — correctness-reviewer (`correctness-003`, conf 0.78), adversarial-reviewer (`adversarial-3`, conf 0.82). Cross-reviewer agreement.
- **Evidence**: `app/models/campaign.rb` and `app/models/attack.rb` have multiple `after_commit ..., on: [:update]` callbacks. `discard` fires these.
- **Impact**: Probably cosmetic at worst (client receives a broadcast for a record the UI then hides via `default_scope -> { kept }` on the next render). But it may cause:
  - Unnecessary Turbo Stream traffic right before deletion.
  - Edge-case errors if a listener assumes the record is still "kept" when processing the broadcast.
  - Log noise in broadcast error handling.

## Proposed Solutions

### Option A: Guard broadcasters with `unless discarded?` (Recommended)

Update each `after_commit ..., on: [:update], ...` clause to also check `unless: :discarded?` so broadcasts skip when the record is being soft-deleted.

```ruby
after_commit :broadcast_attack_progress_update, on: [:update], unless: :discarded?
```

- **Pros**: Minimal code change. Preserves existing broadcast behavior for non-destroy updates.
- **Cons**: Every `after_commit :on [:update]` has to be audited and updated consistently. Easy to miss one.
- **Effort**: Medium (audit all after_commit hooks in both models plus concerns).
- **Risk**: Low.

### Option B: Observe & measure first

Add a Rails log entry when an after_commit broadcast fires on a discarded record, collect production signal for a week, then decide whether Option A is needed.

- **Pros**: Avoids speculative refactor.
- **Cons**: Requires deploy + observation window before acting.
- **Effort**: Small.
- **Risk**: None.

### Option C: Leave as-is, rely on client-side filtering

The client already filters the default-scope'd view on the next fetch, so a single transient broadcast for a discarded record is benign. If no user-facing glitch is reported, no fix is needed.

- **Pros**: Zero churn.
- **Cons**: Invisible edge-case bugs could accumulate in listeners that don't handle soft-deleted records.
- **Effort**: None.
- **Risk**: Medium — deferred until a user-visible bug surfaces.

## Recommendation

**Option A** — guard broadcasters with `unless: :discarded?` now. Confirmed during 2026-04-19 triage.

Rationale for choosing A over B (observe-and-measure):

- The silent-failure-hunter finding in today's review showed this isn't just cosmetic — if any broadcaster *raises* while a record is being discarded (e.g., `clear_campaign_quarantine_if_needed` hitting an already-discarded parent campaign mid-cascade), the exception bubbles out of `destroy` and the user sees a 500 on what looked like a successful delete. That failure mode is real, not hypothetical.
- The audit is bounded (two model files plus their concerns) — we don't gain much by waiting.
- Adding `unless: :discarded?` is a pure subtraction of behavior; it cannot make anything worse than today.

## Implementation Scope (from triage)

Audit all `after_commit ..., on: [:update]` in the soft-deletable models and their concerns, add `unless: :discarded?` consistently. Files to audit:

- `app/models/campaign.rb` — `mark_attacks_complete`, `broadcast_eta_update`, `trigger_priority_rebalance_if_needed` (lines ~165-167).
- `app/models/attack.rb` — `broadcast_attack_progress_update`, `broadcast_index_state`, `clear_campaign_quarantine_if_needed` (lines ~248-250).
- `app/models/concerns/safe_broadcasting.rb` — check for any `after_*` hooks that may need the guard.
- `app/models/concerns/attack_state_machine.rb` — state-transition after_commits that may fire during discard.

Also worth verifying during implementation: does the existing `after_commit :mark_attacks_complete` on Campaign iterate over associated attacks using `attacks` (default-scoped, so already hidden mid-cascade) or `attacks.unscoped`? The `unless: :discarded?` guard protects the callback from firing at all; no interior change needed.

## Test Plan

- Add a spec that destroys a `Campaign` and a top-level `Attack` and asserts the guarded broadcasters are NOT invoked (stub them and assert zero calls during the discard cascade).
- Add a spec that updates a non-discarded record (state transition, name change, etc.) and asserts the broadcasters DO fire as today — the guard must not regress normal updates.
- Extend the existing soft-delete cascade test to confirm no exceptions surface from `destroy`/`destroy!` when a discarded parent's broadcasters would previously have raised (today's silent-failure scenario).
- `just ci-check` green before and after.

## Related

- Origin: Issue [#558](https://github.com/unclesp1d3r/CipherSwarm/issues/558)
- Adjacent: `app/models/concerns/safe_broadcasting.rb`, attack state machine after_commits.
