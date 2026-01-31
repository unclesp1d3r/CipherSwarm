# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Provides state machine functionality for Attack models.
#
# This concern extracts state machine logic from the Attack model to improve
# organization and testability.
#
# States: pending, running, paused, failed, exhausted, completed
#
# Events:
# - accept: Transitions to running
# - run: Transitions pending to running
# - complete: Transitions to completed when all tasks done or hash list cracked
# - pause: Transitions to paused
# - error: Transitions running to failed
# - exhaust: Transitions to completed when all tasks exhausted
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
        transition running: :completed if ->(attack) { attack.tasks.all?(&:completed?) || attack.campaign.completed? }
        transition pending: :completed if ->(attack) { attack.hash_list.uncracked_count.zero? }
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

      # Trigger that the attack has been exhausted. If the attack is in the running state, it will transition to the completed state
      # if all tasks are exhausted. If the attack is in the running state, it will transition to the completed state if the hash list
      # is fully cracked.
      event :exhaust do
        transition running: :completed if ->(attack) { attack.tasks.all?(&:exhausted?) }
        transition running: :completed if ->(attack) { attack.hash_list.uncracked_count.zero? }
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

      ## Transitions

      # Executed after an attack has entered the running state. This sets the start_time attribute to the current time.
      after_transition on: :run do |attack|
        attack.touch(:start_time) # rubocop:disable Rails/SkipsModelValidations
        attack.campaign.touch # rubocop:disable Rails/SkipsModelValidations
      end

      # Executed after an attack has entered the completed state. This sets the end_time attribute to the current time.
      after_transition on: :complete do |attack|
        attack.touch(:end_time) # rubocop:disable Rails/SkipsModelValidations
      end

      # Executed after an attack has been abandoned. This removes all tasks associated with the attack.
      # Wrapped in error handling to ensure transition completes and errors are logged.
      after_transition on: :abandon do |attack|
        task_ids = attack.tasks.pluck(:id)
        task_count = task_ids.size

        begin
          task_agent_info = attack.tasks.includes(:agent).map { |t| "Task #{t.id} (Agent #{t.agent_id})" }.join(", ")

          Rails.logger.info("[Attack #{attack.id}] Abandoning attack for campaign #{attack.campaign_id}, destroying #{task_count} tasks: [#{task_ids.join(', ')}]")
          Rails.logger.info("[Attack #{attack.id}] Tasks with agent assignments: #{task_agent_info}") if task_agent_info.present?

          # Remove tasks to free up for another agent
          attack.tasks.destroy_all

          Rails.logger.info("[Attack #{attack.id}] Tasks destroyed: [#{task_ids.join(', ')}]")

          # Update campaign timestamp
          attack.campaign.touch # rubocop:disable Rails/SkipsModelValidations

          Rails.logger.info("[Attack #{attack.id}] Attack abandoned, campaign #{attack.campaign_id} updated at #{Time.zone.now}")
        rescue StandardError => e
          Rails.logger.error(
            "[Attack #{attack.id}] Error during abandon transition: #{e.class} - #{e.message}. " \
            "Tasks targeted for destruction: [#{task_ids.join(', ')}]"
          )
          raise # Re-raise to rollback the transition
        end
      end

      # Executed after an attack is being paused. This pauses all tasks associated with the attack.
      after_transition any => :paused, :do => :pause_tasks

      # Executed after an attack is being resumed. This resumes all tasks associated with the attack.
      after_transition paused: any, do: :resume_tasks

      # Broadcast progress updates for state changes
      after_transition any => %i[running completed exhausted failed paused], do: :broadcast_attack_progress_update

      # Executed after an attack has been completed. This completes the hash list for the campaign and updates the campaign's updated_at timestamp.
      after_transition any => :completed, :do => :complete_hash_list
      after_transition any => :completed, :do => :touch_campaign

      # Executed before an attack is marked completed. This completes all remaining tasks associated with the attack if the hash list is fully cracked.
      before_transition on: :complete do |attack|
        attack.tasks.each(&:complete!) if attack.hash_list.uncracked_count.zero?
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
    other_incomplete.each(&:complete)
  end

  # Pauses all tasks associated with the current object.
  # Iterates through each task and calls the `pause` method on it.
  def pause_tasks
    tasks.without_state(:paused).each(&:pause)
  end

  # Resumes all tasks associated with the current object.
  # Iterates through each task and calls the `resume` method on it.
  def resume_tasks
    tasks.find_each(&:resume)
  end

  # Updates the `updated_at` timestamp of the associated campaign.
  #
  # This method calls the `touch` method on the campaign, which updates
  # the `updated_at` timestamp to the current time.
  #
  # @return [void]
  def touch_campaign
    campaign.touch # rubocop:disable Rails/SkipsModelValidations
  end
end
