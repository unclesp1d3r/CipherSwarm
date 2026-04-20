---
title: Migrating Rails soft-delete from paranoia to discard while preserving behavior
date: 2026-04-19
category: best-practices
module: soft-delete
problem_type: best_practice
component: rails_model
severity: high
applies_when:
  - Migrating a Rails app from the unmaintained paranoia gem to discard
  - Adopting Discard::Model on models that have `dependent: :destroy` cascades
  - Adopting Discard::Model on models that carry a `counter_cache: true` belongs_to
  - Adopting Discard::Model on models with `after_commit ..., on: [:update]` broadcasters
  - Preserving the "destroy means soft-delete" contract for existing controllers and callers
tags: [soft-delete, discard, paranoia, rails-migration, counter-cache, default-scope, hotwire-turbo]
---

# Migrating Rails soft-delete from paranoia to discard while preserving behavior

## Context

The `paranoia` gem is effectively unmaintained — maintainers have publicly stated they cannot keep up and direct users to alternatives. `discard` is the community-standard replacement, actively maintained, and — for CipherSwarm's air-gapped deployment — pure Ruby with no Internet dependencies. On paper it is a one-line swap.

In practice, `discard` and `paranoia` differ in four non-obvious ways that a naive "replace `acts_as_paranoid` with `include Discard::Model`" migration will silently regress. None of these are documented prominently in the discard README; they are the migration's hidden interaction costs. This doc captures them so the next engineer doing a paranoia→discard migration on this codebase (or an adjacent one) doesn't have to rediscover them.

Resolved as part of issue #558 / PR [#864](https://github.com/unclesp1d3r/CipherSwarm/pull/864). The migration touched `Campaign` and `Attack` — the only two models in the codebase using `acts_as_paranoid`.

## Guidance

Do all four of these when migrating from paranoia to discard. Skipping any one produces a silent regression that only surfaces in specific (and often rare) cases.

### 1. `destroy` must be overridden — discard does NOT override it

Paranoia overrides `destroy` to set `deleted_at`; discard does not. A plain `include Discard::Model` leaves `model.destroy` as standard ActiveRecord destroy — which hard-deletes the row. Every controller, service, and caller in the codebase that calls `.destroy` silently starts hard-deleting.

The wrapper must run destroy callbacks so `dependent: :destroy` cascades still fire, but replace the DELETE with `discard`:

```ruby
# app/models/concerns/soft_deletable.rb
def destroy
  return self if discarded?

  result = with_transaction_returning_status do
    run_callbacks(:destroy) do
      discarded = discard
      raise ActiveRecord::Rollback unless discarded
      discarded
    end
  end
  result ? self : false
end

def destroy!
  result = destroy
  return self if result
  raise ActiveRecord::RecordNotDestroyed.new("Failed to discard #{self.class} id=#{id}", self)
end
```

Key details:

- **`run_callbacks(:destroy)`** fires `before_destroy` and `after_destroy` hooks, which is what makes `dependent: :destroy` cascade. Omitting it breaks every existing cascade silently.
- **`return self if discarded?`** makes a second `destroy` call a no-op. Without this, cascades can fire twice when records are re-destroyed.
- **`result ? self : false`** respects AR's documented halted-callback contract. If a `before_destroy` throws `:abort`, `destroy` must return `false` (not `self`), otherwise callers using `if record.destroy` see truthy on halt.
- **`raise ActiveRecord::Rollback unless discarded`** unwinds the transaction if `discard` itself fails. Without it, a partial cascade can commit some children's discards before the parent fails, leaving an inconsistent state.
- **`destroy!` includes the record id in the raised message** — a generic "Failed to discard Campaign" is diagnostically useless in Sentry; the id makes it actionable.

**Cascade design decision** — `run_callbacks(:destroy)` walks `dependent: :destroy` and calls `.destroy` on each child. For soft-deletable children, the cascade soft-deletes (because their `destroy` is also overridden). For non-soft-deletable children, it hard-deletes. This is usually what you want (parent soft-deleted, non-paranoid children hard-deleted), but it's worth confirming consciously per model — a soft-deletable parent with non-soft-deletable children will lose child rows on discard, not hide them.

### 2. `default_scope { kept }` collides with Discard's built-in `.discarded` scope

Paranoia installs an implicit default scope that hides soft-deleted rows. To preserve that behavior, add `default_scope -> { kept }`. **But** this combines with Discard's built-in `.discarded` scope into an always-empty set: `WHERE deleted_at IS NULL AND deleted_at IS NOT NULL`. Callers expecting `.discarded` to return the soft-deleted rows see `[]` instead.

Fix: redefine the scope to unscope only the `:deleted_at` predicate:

```ruby
default_scope -> { kept }

# Unscoping only :deleted_at (not `.unscoped`) preserves any future
# default_scope additions unrelated to soft-delete.
scope :discarded, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }
```

Avoid the alternative `scope :discarded, -> { unscoped.where.not(deleted_at: nil) }` — it drops every default_scope clause, which is a bigger footgun if the model later acquires unrelated default_scope filters.

### 3. `counter_cache: true` decrements do NOT fire on discard

Rails wires `belongs_to :parent, counter_cache: true`'s decrement to the DELETE path. `discard` is an UPDATE (sets `deleted_at`), so the counter never decrements. After a soft-delete, `parent.children_count` stays stale and every downstream caller (labels, "paused?" checks, completion detection) sees an incorrect count.

Maintain the counter manually with an opt-in `after_discard` hook. In CipherSwarm's SoftDeletable concern:

```ruby
def self.discards_with_counter_cache(column, on:)
  after_discard do
    # reflect_on_association so custom `foreign_key:` settings work —
    # not every `belongs_to :parent` maps to a `parent_id` column.
    reflection = self.class.reflect_on_association(on)
    parent_fk = public_send(reflection.foreign_key)
    next unless parent_fk

    # Counter caches intentionally skip validations (Rails idiom).
    reflection.klass.decrement_counter(column, parent_fk) # rubocop:disable Rails/SkipsModelValidations
  end
end
```

Usage:

```ruby
class Attack < ApplicationRecord
  include SoftDeletable
  discards_with_counter_cache :attacks_count, on: :campaign

  belongs_to :campaign, counter_cache: true
end
```

`Campaign.decrement_counter` uses `unscoped` internally, so it works even when the parent is in the middle of a cascading discard. Grep the codebase for `counter_cache:` on every soft-deletable model before declaring the migration done — every such belongs_to needs a matching `discards_with_counter_cache`.

### 4. `after_commit ..., on: [:update]` broadcasters fire during discard

Because `discard` is an UPDATE, every `after_commit ..., on: [:update]` callback fires during a soft-delete. If any of those callbacks push Turbo Stream updates, trigger jobs, or assume the record is `kept?`, they run against a record that is seconds away from being hidden by `default_scope`. At best: noise. At worst: a callback raises (broadcasting to a channel that no longer exists, iterating children that have already cascaded), and the exception bubbles out of `destroy` — the user sees a 500 on what looked like a successful delete.

Fix: add `unless: :discarded?` to every `after_commit ..., on: [:update]` in every soft-deletable model AND any concerns those models include:

```ruby
after_commit :broadcast_attack_progress_update, on: [:update], unless: :discarded?
after_update_commit :broadcast_index_state, if: :saved_change_to_state?, unless: :discarded?
after_commit :clear_campaign_quarantine_if_needed, on: [:update], unless: :discarded?
```

Audit scope for this step: grep `after_commit.*:update\|after_update_commit` across the soft-deletable models and every concern they `include`. Easy to miss one — `attack_state_machine.rb` and similar state-machine concerns are common culprits.

## Why This Matters

The migration's value proposition is *zero observable change* to callers — paranoia's contract (`destroy` soft-deletes, queries hide deleted rows, cascades fire, counter caches stay accurate, broadcasts fire only for real updates) must be preserved. All four gaps above are latent: the default test suite won't surface them without targeted tests, so regressions land silently and only manifest in production under specific conditions. The tests added in PR #864 (see `Examples` below) pin each gap explicitly.

## When to Apply

Apply this full playbook when:

- A Rails model has `acts_as_paranoid` and you are replacing the gem dependency.
- A Rails model is adopting `Discard::Model` for the first time AND the team expects paranoia-style semantics (`destroy` = soft-delete, queries hide deleted rows, cascades fire).
- A Rails model has `belongs_to :parent, counter_cache: true` AND the team is adopting soft-delete on that child.

Do not apply this playbook when:

- The team is adopting `Discard::Model` greenfield with explicit `.discard!` calls in controllers and explicit `.kept` scoping at every call site. That is the discard-native path and is cleaner long-term; it just requires touching every call site rather than doing a minimal-diff migration.
- Soft-delete is being added to a model with no existing callers relying on `destroy` semantics — then `.discard!` directly in the callers is simpler.

## Examples

See [`app/models/concerns/soft_deletable.rb`](../../../app/models/concerns/soft_deletable.rb) for the full concern implementation and REASONING block (shipped as part of PR #864 commit `933e10c`).

See [`spec/models/campaign_spec.rb`](../../../spec/models/campaign_spec.rb) `describe "soft delete"` and [`spec/models/attack_spec.rb`](../../../spec/models/attack_spec.rb) `describe "soft delete"` for the canonical regression tests covering each guidance item:

- Destroy contract: `destroy` returns `false` on `:abort`, `destroy!` raises, partial cascades roll back.
- Scope behavior: `.kept` / `.discarded` / `.unscoped` / `discarded?` / `kept?`.
- Cascade: Campaign → Attack soft-delete, Attack → Task hard-delete.
- Counter cache: `campaign.attacks_count` decrements on `attack.destroy`.
- Broadcast guards: `after_commit on: [:update]` callbacks do NOT fire on discard, DO fire on normal updates.

## Related

- Origin issue: [#558](https://github.com/unclesp1d3r/CipherSwarm/issues/558)
- Origin PR: [#864](https://github.com/unclesp1d3r/CipherSwarm/pull/864) — commits `c6a5642` (initial migration), `08e29cd` (counter-cache fix discovered during review), `933e10c` (concern extraction + contract fixes + broadcast guards).
- External: [discard gem](https://github.com/jhawthorn/discard) — note that the README does not surface the four gotchas above; they were discovered during review.
- External: [paranoia maintenance status](https://github.com/rubysherpas/paranoia#readme)
