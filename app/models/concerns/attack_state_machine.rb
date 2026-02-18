# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Provides state machine functionality for Attack models.
#
# REASONING:
# - Summary: Extract state machine into concern for better organization and testability
# - Alternatives: Keep in model (monolithic), separate service object (over-engineering)
# - Decision: Concern pattern aligns with Rails conventions and keeps Attack model focused
#
# States: pending, running, paused, failed, exhausted, completed
#
# Events:
# - accept: Transitions to running
# - run: Transitions pending to running
# - complete: Transitions to completed when all tasks done or hash list cracked
# - pause: Transitions to paused
# - error: Transitions running to failed
# - exhaust: Transitions to exhausted when all tasks exhausted
# - cancel: Transitions to failed
# - reset: Transitions to pending for re-running
# - resume: Transitions paused to pending
# - abandon: Transitions running to pending to free for another agent
module AttackStateMachine
  extend ActiveSupport::Concern

  included do
    state_machine :state, initial: :pending do
      # Trigger that an agent has accepted the attack. This can only be triggered when the attack is in the pending state.
      event :accept do
        transition all - %i[completed exhausted] => :running
      end

      # Trigger that the attack has been started. This can only be triggered when the attack is in the pending state.
      event :run do
        transition pending: :running
      end

      # Trigger that the attack has been completed. If the attack is in the running state, it will transition to the completed state
      # if all tasks are completed or the hash list is fully cracked. If the attack is in the pending state, it will transition to the
      # completed state if the hash list is fully cracked.
      event :complete do
        transition running: :completed if ->(attack) { !attack.tasks.without_state(:completed).exists? || attack.campaign.completed? }
        transition pending: :completed if ->(attack) { (attack.hash_list&.uncracked_count || 0).zero? }
        transition all - [:running] => same
      end

      # Trigger that the attack has been paused. If the attack is in the running or pending state, it will transition to the paused state.
      event :pause do
        transition %i[running pending] => :paused
        transition any => same
      end

      # Trigger that the attack has encountered an error. If the attack is in the running state, it will transition to the failed state.
      event :error do
        transition running: :failed
        transition any => same
      end

      # Trigger that the attack has been exhausted. If the attack is in the running state, it will transition to the exhausted state
      # if all tasks are exhausted. If the attack is in the running state, it will transition to the exhausted state if the hash list
      # is fully cracked.
      event :exhaust do
        transition running: :exhausted if ->(attack) { !attack.tasks.without_state(:exhausted).exists? }
        transition running: :exhausted if ->(attack) { (attack.hash_list&.uncracked_count || 0).zero? }
        transition any => same
      end

      # Trigger that the attack has been canceled. If the attack is in the pending or running state, it will transition to the failed state.
      event :cancel do
        transition %i[pending running] => :failed
      end

      # Trigger that the attack has been reset. If the attack is in the failed, completed, or exhausted state, it will transition to the pending state.
      # This is only used when the attack needs to be re-run, such as when it has been modified, the hash list has changed, etc.
      event :reset do
        transition %i[failed completed exhausted] => :pending
      end

      # Trigger that the attack is being resumed. If the attack is in the paused state, it will transition to the pending state.
      event :resume do
        transition paused: :pending
        transition any => same
      end

      # Trigger that the agent has abandoned the attack. If the attack is in the running state, it will transition to the pending state.
      # This is to free the attack up for another agent to pick up.
      event :abandon do
        transition running: :pending
        transition any => same
      end

      after_transition on: :run do |attack|
        attack.touch(:start_time) # rubocop:disable Rails/SkipsModelValidations
        attack.campaign.touch # rubocop:disable Rails/SkipsModelValidations
      end
      after_transition on: :complete do |attack|
        attack.touch(:end_time) # rubocop:disable Rails/SkipsModelValidations
      end
      after_transition on: :abandon do |attack|
        task_ids = attack.tasks.pluck(:id)
        Rails.logger.info("[AttackAbandon] Attack #{attack.id}: destroying #{task_ids.size} tasks [#{task_ids.join(', ')}]")
        attack.tasks.destroy_all
        attack.campaign.touch # rubocop:disable Rails/SkipsModelValidations
      rescue StandardError => e
        backtrace = e.backtrace&.first(5)&.join("\n           ") || "Not available"
        Rails.logger.error("[AttackAbandon] Attack #{attack.id} error: #{e.class} - #{e.message}\n           Backtrace: #{backtrace}")
        raise
      end
      after_transition any => :paused, :do => :pause_tasks
      after_transition paused: any, do: :resume_tasks
      after_transition any => %i[running completed exhausted failed paused], do: :broadcast_attack_progress_update
      after_transition any => :completed, :do => :complete_hash_list
      after_transition any => :completed, :do => :touch_campaign
      before_transition on: :complete do |attack|
        if attack.hash_list.uncracked_count.zero?
          attack.tasks.without_state(:completed).find_each(&:complete!)
        end
      end

      state :paused
      state :failed
      state :exhausted
      state :pending
    end
  end
  private

  # Completes other incomplete attacks for the campaign if there are no uncracked hashes left.
  #
  # This method checks if the campaign has zero uncracked hashes. If true, it iterates
  # through all other incomplete attacks (excluding self) and marks them as complete.
  # The exclusion of self prevents potential repeated queries when multiple attacks complete.
  #
  # @return [void]
  def complete_hash_list
    return unless campaign.uncracked_count.zero?

    other_incomplete = campaign.attacks.incomplete.where.not(id: id)
    return if other_incomplete.none?

    Rails.logger.info("[Attack #{id}] Completing #{other_incomplete.count} related incomplete attacks")
    other_incomplete.each do |attack|
      attack.complete! if attack.can_complete?
    rescue StandardError => e
      Rails.logger.warn("[Attack #{id}] Failed to complete attack #{attack.id}: #{e.message}")
    end
  end

  def pause_tasks
    tasks.without_state(:paused).each(&:pause)
  end

  def resume_tasks
    tasks.find_each(&:resume)
  end

  def touch_campaign
    campaign.touch # rubocop:disable Rails/SkipsModelValidations
  end
end
