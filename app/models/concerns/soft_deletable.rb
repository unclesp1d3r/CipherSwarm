# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Concern: SoftDeletable
#
# Wraps the discard gem to provide paranoia-compatible soft-delete semantics:
# `destroy` soft-deletes (sets :deleted_at) while still running destroy
# callbacks so `dependent: :destroy` cascades behave as they did under
# paranoia. Soft-deleted rows are hidden from default queries.
#
# REASONING:
# - Summary: Consolidates the paranoia -> discard migration boilerplate
#   (include, discard_column, default_scope, scope override, destroy
#   overrides, optional counter-cache hook) into one place so future
#   corrections land once instead of drifting across Campaign and Attack.
# - Alternatives:
#   - Duplicate across each soft-deletable model: rejected — three
#     reviewers flagged character-for-character duplication; any fix
#     (e.g., halted-callback contract, broadcast guards) would need to
#     land in two files or drift silently.
#   - Switch controllers to call `.discard!` directly: rejected — larger
#     diff, deferred as a separate issue from the migration.
# - Decision: Concern keeps the migration minimal-diff at the controller
#   boundary while giving us a single file to iterate on soft-delete
#   semantics. `default_scope -> { kept }` preserves paranoia's implicit
#   filter; `destroy` is wrapped in `run_callbacks(:destroy) { discard }`
#   so AR destroy callbacks (including `dependent: :destroy` cascade)
#   continue to fire. Counter-cache maintenance is opt-in via
#   `discards_with_counter_cache` because Rails wires the decrement to
#   the DELETE path, which our override bypasses.
# - Performance implications: None — behavior identical to paranoia plus
#   one extra UPDATE on each counter_cache decrement (same number of
#   writes paranoia emitted).
#
# Usage:
#   class Campaign < ApplicationRecord
#     include SoftDeletable
#   end
#
#   class Attack < ApplicationRecord
#     include SoftDeletable
#     discards_with_counter_cache :attacks_count, on: :campaign
#   end
#
# Scopes:
#   Model.all        # kept records only (default scope)
#   Model.kept       # same as .all, explicit
#   Model.discarded  # soft-deleted only (bypasses default_scope)
#   Model.unscoped   # all records including soft-deleted
#
# Queries: reach for `.unscoped` or `.discarded` when admin/audit code
# needs to see soft-deleted rows; default queries continue to hide them.
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    include Discard::Model
    # Explicit pin against upstream Discard default changes. The column
    # itself is the one paranoia used — reused so no schema migration is
    # needed to adopt discard.
    self.discard_column = :deleted_at

    # Reproduces paranoia's implicit filter: soft-deleted rows are hidden
    # from every default query. Reach for `.unscoped` to see them.
    default_scope -> { kept }

    # Discard's built-in `.discarded` combines with `default_scope { kept }`
    # (`deleted_at IS NULL AND deleted_at IS NOT NULL`) into an empty set.
    # Unscoping just the :deleted_at predicate restores the expected
    # behavior while leaving any additional default_scope clauses intact.
    scope :discarded, -> { unscope(where: :deleted_at).where.not(deleted_at: nil) }
  end

  class_methods do
    # Opt-in counter-cache maintenance for soft-delete.
    #
    # Rails' `belongs_to :parent, counter_cache: true` wires the counter
    # decrement to the DELETE path. `discard` sets :deleted_at via UPDATE,
    # so the counter decrement never fires. Models that rely on a counter
    # cache opt in here to get a matching decrement on `after_discard`.
    #
    #   discards_with_counter_cache :attacks_count, on: :campaign
    #
    # @param column [Symbol] the counter column on the parent table
    # @param on [Symbol] the belongs_to association name on this model
    def discards_with_counter_cache(column, on:)
      # Validate at declaration time so misuse fails fast with an actionable
      # message instead of a NoMethodError on every discard call.
      reflection = reflect_on_association(on)
      raise ArgumentError, "discards_with_counter_cache: no association `#{on}` on #{name}" unless reflection
      raise ArgumentError, "discards_with_counter_cache: `#{on}` is not a belongs_to (got #{reflection.macro})" unless reflection.macro == :belongs_to

      after_discard do
        # `self` here is the record; re-resolve the reflection so per-instance
        # subclassing (STI) still gets the right parent class.
        instance_reflection = self.class.reflect_on_association(on)
        parent_fk = public_send(instance_reflection.foreign_key)
        next unless parent_fk

        # Counter caches intentionally skip validations and callbacks
        # (the Rails idiom for keeping cached counts in sync).
        instance_reflection.klass.decrement_counter(column, parent_fk) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end

  # Preserve paranoia's destroy-means-soft-delete contract: `destroy` runs
  # the standard destroy callbacks (so `dependent: :destroy` cascades to
  # children and `before_destroy` / `after_destroy` hooks still fire) but
  # replaces the DELETE with `discard` (sets deleted_at). The `discarded?`
  # guard makes a second `destroy` a no-op so cascades never fire twice.
  #
  # Respects ActiveRecord's halted-callback contract: if a `before_destroy`
  # throws `:abort`, `with_transaction_returning_status` returns `false`
  # and we propagate that — partial child cascades are rolled back because
  # the transaction also unwinds.
  #
  # Also sets `@destroyed` and `@_trigger_destroy_callback` after a successful
  # discard so `destroyed?` and `after_destroy_commit` hooks behave the same
  # way they would after a real DELETE — AR's internal destroy bookkeeping is
  # tied to `destroy_row`, which our override skips.
  def destroy
    return self if discarded?

    result = with_transaction_returning_status do
      # If run_callbacks halts (via :abort) or discard itself fails, roll
      # the transaction back so any partial child cascade is undone.
      run_callbacks(:destroy) do
        discarded = discard
        raise ActiveRecord::Rollback unless discarded

        # Mirror AR's `destroy_row`-driven bookkeeping so callers relying on
        # the standard destroy contract see consistent state.
        @destroyed = true
        @_trigger_destroy_callback = true
        discarded
      end
    end
    result ? self : false
  end

  def destroy!
    destroyed = destroy
    return self if destroyed
    raise ActiveRecord::RecordNotDestroyed.new("Failed to discard #{self.class} id=#{id}", self)
  end
end
