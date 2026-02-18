# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Provides state machine functionality for Task models.
#
# REASONING:
# - Summary: Extract state machine into concern for better organization and testability
# - Alternatives: Keep in model (441+ lines), separate service object (over-engineering)
# - Decision: Concern pattern aligns with AttackStateMachine and Rails conventions
# - Performance implications: None, purely organizational
#
# States: pending, running, paused, failed, exhausted, completed
#
# Events:
# - accept: Agent accepts task, transitions to running
# - run: Transitions pending to running
# - complete: Marks running tasks as completed
# - pause: Pauses pending/running tasks
# - resume: Resumes paused tasks to pending
# - error: Marks running tasks as failed
# - exhaust: Marks running tasks as exhausted
# - cancel: Cancels pending/running tasks (to failed)
# - accept_crack: Completes or keeps running depending on uncracked hashes
# - accept_status: Updates task to running on status receipt
# - abandon: Returns running tasks to pending (triggers attack abandon)
# - retry: Returns failed tasks to pending with incremented retry count
# - preempt: Returns running tasks to pending for priority preemption (no attack abandon)
# rubocop:disable Metrics/ModuleLength
module TaskStateMachine
  extend ActiveSupport::Concern

  included do
    state_machine :state, initial: :pending do
      event :accept do
        transition pending: :running
        transition running: same
      end

      event :run do
        transition pending: :running
        transition any => same
      end

      event :complete do
        transition running: :completed
        transition pending: :completed if ->(task) { task.attack.hash_list.uncracked_count.zero? }
        transition any - [:running] => same
      end

      event :pause do
        transition %i[pending running] => :paused
        transition any => same
      end

      event :resume do
        transition paused: :pending
        transition any => same
      end

      event :error do
        transition running: :failed
      end

      event :exhaust do
        transition running: :exhausted
      end

      event :cancel do
        transition %i[pending running] => :failed
      end

      event :accept_crack do
        transition running: :completed, unless: :uncracked_remaining
        transition running: same
        transition all - %i[running completed] => :running
      end

      event :accept_status do
        transition %i[pending running] => :running
        transition paused: same
      end

      event :abandon do
        transition running: :pending
      end

      event :retry do
        transition failed: :pending
      end

      # Preempt returns a running task to pending without triggering attack abandon.
      # Used by TaskPreemptionService for priority-based preemption.
      event :preempt do
        transition running: :pending
      end

      after_transition to: :running do |task|
        task.send(:log_state_transition, "running", "Task accepted and running")
        task.attack.accept
      end

      after_transition to: :completed do |task|
        uncracked = task.hash_list.uncracked_count
        task.send(:log_state_transition, "completed", "Uncracked hashes: #{uncracked}")
        task.attack.complete if task.attack.can_complete?
        task.hashcat_statuses.delete_all
      end

      after_transition to: :exhausted do |task|
        task.send(:log_state_transition, "exhausted", "Keyspace exhausted")
        task.attack.exhaust if task.attack.can_exhaust?
        task.hashcat_statuses.delete_all
      end

      after_transition on: :abandon do |task|
        task.send(:log_state_transition, "abandoned", "Triggering attack abandonment")
        task.attack.abandon
        task.send(:mark_stale_safely)
      end

      after_transition on: :resume do |task|
        task.send(:log_state_transition, "resumed", "Marking as stale")
        task.update(stale: true)
      end

      after_transition to: :paused do |task|
        task.send(:log_state_transition, "paused", "Task execution paused")
      end

      after_transition on: :retry do |task|
        task.send(:log_state_transition, "pending", "Task retried")
        # rubocop:disable Rails/SkipsModelValidations
        task.update_columns(retry_count: task.retry_count + 1, last_error: nil)
        # rubocop:enable Rails/SkipsModelValidations
      end

      after_transition on: :preempt do |task|
        task.send(:log_state_transition, "pending", "Task preempted for higher priority attack")
        # rubocop:disable Rails/SkipsModelValidations
        task.update_columns(stale: true, preemption_count: task.preemption_count + 1)
        # rubocop:enable Rails/SkipsModelValidations
      end

      after_transition on: :error do |task, transition|
        StateChangeLogger.log_task_transition(
          task: task,
          event: :error,
          transition: { from: transition.from, to: transition.to },
          context: { reason: task.last_error || "unknown" }
        )
      end

      after_transition on: :cancel do |task, transition|
        StateChangeLogger.log_task_transition(
          task: task,
          event: :cancel,
          transition: { from: transition.from, to: transition.to },
          context: { reason: "Task manually cancelled" }
        )
      end

      after_transition on: :accept_status do |task, transition|
        StateChangeLogger.log_task_transition(
          task: task,
          event: :accept_status,
          transition: { from: transition.from, to: transition.to },
          context: { reason: "Status update received" }
        )
      end

      after_transition on: :accept_crack do |task, transition|
        next if transition.to == "completed"

        StateChangeLogger.log_task_transition(
          task: task,
          event: :accept_crack,
          transition: { from: transition.from, to: transition.to },
          context: { reason: "Crack accepted, uncracked hashes remaining" }
        )
      end

      # Shared broadcast hook: ensures all task state changes push attack progress
      # updates to the UI. Covers error, cancel, retry, accept_status, accept_crack,
      # preempt, and all other transitions. Excludes abandon (which triggers attack.abandon
      # destroying all tasks, making broadcast unreliable).
      after_transition do |task, transition|
        next if transition.event == :abandon
        task.send(:safe_broadcast_attack_progress_update)
      end

      after_transition any - [:pending] => any, do: :update_activity_timestamp

      state :completed
      state :running
      state :paused
      state :failed
      state :exhausted
      state :pending
    end
  end

  private

  def log_state_transition(new_state, message)
    Rails.logger.info(
      "[Task #{id}] Agent #{agent_id} - Attack #{attack_id} - " \
      "State change: #{state_was} -> #{new_state} - #{message}"
    )
  end

  def mark_stale_safely
    # Use update_columns to avoid stale object errors from optimistic locking
    # rubocop:disable Rails/SkipsModelValidations
    update_columns(stale: true)
    # rubocop:enable Rails/SkipsModelValidations
  rescue StandardError => e
    Rails.logger.error(
      "[Task #{id}] Error updating stale flag in abandon callback - " \
      "Error: #{e.class} - #{e.message} - #{Time.current}"
    )
    # Don't re-raise - this is a non-critical update
  end
end
# rubocop:enable Metrics/ModuleLength
