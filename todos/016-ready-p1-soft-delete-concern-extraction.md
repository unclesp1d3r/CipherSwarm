---
status: ready
priority: p1
issue_id: '016'
tags: [code-review, refactoring, architecture, soft-delete, dry]
dependencies: []
origin_issue: '558'
triaged: 2026-04-19
---

# Extract Soft-Delete Boilerplate Into a Concern

## Problem Statement

After the paranoia → discard migration (issue #558), `Campaign` and `Attack` carry ~20 lines of identical soft-delete setup (include, `discard_column`, `default_scope -> { kept }`, redefined `.discarded` scope, `destroy` / `destroy!` overrides). The duplication is real (not speculative), the intent is documented (replace paranoia), and future corrections (e.g., the halted-callback contract issue in todo 017) would have to land in both places.

## Findings

- **Source**: ce:review run `20260419-191817-0c8476b9` — maintainability-reviewer (`maint-001`, conf 0.82), project-standards-reviewer (`ps-002`, conf 0.90), kieran-rails-reviewer (`kieran-rails-002`, conf 0.75). Three independent reviewers flagged the same duplication.
- **Evidence**: Character-for-character-identical blocks at `app/models/campaign.rb:93-137` and `app/models/attack.rb:107-154`.
- **Impact**: Any future change to soft-delete semantics must be applied in two places or drift silently.

## Proposed Solutions

### Option A: Extract to `app/models/concerns/soft_deletable.rb` (Recommended)

Move the `include Discard::Model`, `self.discard_column = :deleted_at`, `default_scope -> { kept }`, redefined `.discarded` scope, and `destroy` / `destroy!` overrides into a single concern. Both `Campaign` and `Attack` then `include SoftDeletable`.

The concern must include a REASONING block at the top of the file per `AGENTS.md` ("Service objects and concerns require a REASONING block"). The REASONING should cover:

- Why a concern was chosen over per-model duplication (real duplication across two models; future single soft-delete change should land once).

- Why `default_scope -> { kept }` is used despite DHH-style opposition (migration from paranoia preserved an implicit filter; explicit-`.kept` refactor is deferred to a separate issue).

- Why `destroy` is overridden instead of switching controllers to call `.discard!` (minimal-diff migration path; controller changes are a separate refactor).

- Why `.discarded` is redefined (Discard's built-in scope combines with `default_scope`'s `deleted_at IS NULL` clause into an empty set).

- **Pros**: Single source of truth. Adding soft-delete to a third model becomes a one-line include. Consolidates the REASONING rather than splitting rationale comments across two files.

- **Cons**: Concerns can hide behavior from readers who grep for `destroy` in a model file. Requires careful RSpec testing to avoid regressions in either model.

- **Effort**: Small (1-2 hours including tests).

- **Risk**: Low — straightforward Rails concern refactor with existing spec coverage.

### Option B: Leave duplicated for now

- **Pros**: Zero churn, avoids adding an abstraction before a third use case exists.
- **Cons**: Violates AGENTS.md "Service objects and concerns require a REASONING block" spirit (rationale is currently split between two model files). Any subsequent change (e.g., todo 017) must ship in two places.
- **Effort**: None.
- **Risk**: Low in the short term; grows as additional soft-delete logic accumulates.

## Recommendation

Option A. The duplication is real and the project rules already require a REASONING block for concerns — consolidating the rationale into one place is a net win over two matching in-line comments.

**Note added during triage (2026-04-19):** PR #864's follow-up commit `08e29cd` added an `after_discard :decrement_campaign_attacks_counter` callback on `Attack` (counter-cache maintenance). Only `Attack` has a `counter_cache: true` belongs_to, so this callback is model-specific. Design the concern so callers can opt into counter-cache wiring — e.g., a class method `discards_with_counter_cache(:attacks_count, on: :campaign)` in the concern — rather than duplicating the callback in Campaign when it doesn't apply.

## Test Plan

- Existing `describe "soft delete"` blocks in `spec/models/campaign_spec.rb` and `spec/models/attack_spec.rb` must continue to pass with no changes.
- `just ci-check` remains green.
- Optional: add a `spec/models/concerns/soft_deletable_spec.rb` using an anonymous test model to pin the contract at the concern level.

## Related

- Origin: Issue [#558](https://github.com/unclesp1d3r/CipherSwarm/issues/558)
- Related: todo 017 (halted-callback contract fix — should land in the concern once extracted).
