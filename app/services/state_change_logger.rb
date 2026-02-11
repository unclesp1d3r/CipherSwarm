# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# StateChangeLogger provides centralized, structured logging for state machine transitions.
#
# This service consolidates the logging patterns used across models (Agent, Attack, Task, Campaign)
# to provide consistent formatting and reduce code duplication.
#
# @example Task state change logging
#   StateChangeLogger.log_task_transition(
#     task: task,
#     event: :accept,
#     transition: { from: "pending", to: "running" }
#   )
#   # => "[Task 123] Agent 456 - Attack 789 - State change: pending -> running (accept)"
#
# @example Agent lifecycle logging
#   StateChangeLogger.log_agent_lifecycle(
#     agent: agent,
#     event: :activate,
#     transition: { from: "pending", to: "active" }
#   )
#   # => "[AgentLifecycle] activate: agent_id=123 state_change=pending->active"
#
# @example Attack state change logging
#   StateChangeLogger.log_attack_transition(
#     attack: attack,
#     event: :run,
#     transition: { from: "pending", to: "running" }
#   )
#   # => "[AttackLifecycle] run: attack_id=123 state_change=pending->running"
#
# @example API error logging
#   StateChangeLogger.log_api_error(
#     error_code: "TASK_ACCEPT_FAILED",
#     ids: { agent_id: 123, task_id: 456 },
#     errors: ["Invalid state transition"]
#   )
#   # => "[APIError] TASK_ACCEPT_FAILED - Agent 123 - Task 456 - Errors: Invalid state transition - 2024-01-01 12:00:00"
#
class StateChangeLogger
  class << self
    # Logs a task state transition.
    #
    # @param task [Task] the task that transitioned
    # @param event [Symbol, String] the event that triggered the transition
    # @param transition [Hash] transition details with :from and :to keys
    # @param context [Hash] additional context to log
    def log_task_transition(task:, event:, transition:, context: {})
      message = "[Task #{task.id}] Agent #{task.agent_id} - Attack #{task.attack_id} - " \
                "State change: #{transition[:from]} -> #{transition[:to]} (#{event})"
      message += " - #{format_context(context)}" if context.present?
      Rails.logger.info(message)
    end

    # Logs an agent lifecycle event.
    #
    # @param agent [Agent] the agent that transitioned
    # @param event [Symbol, String] the event that triggered the transition
    # @param transition [Hash] transition details with :from and :to keys
    # @param context [Hash] additional context to log
    def log_agent_lifecycle(agent:, event:, transition:, context: {})
      message = "[AgentLifecycle] #{event}: agent_id=#{agent.id} state_change=#{transition[:from]}->#{transition[:to]}"
      message += " #{format_context(context)}" if context.present?
      Rails.logger.info(message)
    end

    # Logs an attack state transition.
    #
    # @param attack [Attack] the attack that transitioned
    # @param event [Symbol, String] the event that triggered the transition
    # @param transition [Hash] transition details with :from and :to keys
    # @param context [Hash] additional context to log
    def log_attack_transition(attack:, event:, transition:, context: {})
      message = "[AttackLifecycle] #{event}: attack_id=#{attack.id} state_change=#{transition[:from]}->#{transition[:to]}"
      message += " #{format_context(context)}" if context.present?
      Rails.logger.info(message)
    end

    # Logs a campaign state change.
    #
    # @param campaign [Campaign] the campaign
    # @param event [Symbol, String] the event
    # @param context [Hash] additional context
    def log_campaign_event(campaign:, event:, context: {})
      message = "[CampaignLifecycle] #{event}: campaign_id=#{campaign.id}"
      message += " #{format_context(context)}" if context.present?
      Rails.logger.info(message)
    end

    # Logs an API error with structured format.
    #
    # @param error_code [String] the error code (e.g., "TASK_ACCEPT_FAILED")
    # @param ids [Hash] resource IDs (:agent_id, :task_id, :attack_id)
    # @param errors [Array<String>, String] the error messages
    # @param context [Hash] additional context
    def log_api_error(error_code:, ids: {}, errors: [], context: {})
      parts = ["[APIError] #{error_code}"]
      parts << "Agent #{ids[:agent_id]}" if ids[:agent_id]
      parts << "Task #{ids[:task_id]}" if ids[:task_id]
      parts << "Attack #{ids[:attack_id]}" if ids[:attack_id]

      error_messages = Array(errors).join(", ")
      parts << "Errors: #{error_messages}" if error_messages.present?
      parts << format_context(context) if context.present?
      parts << Time.current.to_s

      Rails.logger.error(parts.join(" - "))
    end

    # Logs a data cleanup operation.
    #
    # @param resource_type [String] the type of resource being cleaned
    # @param deleted_count [Integer] the number of records deleted
    # @param cutoff [Time] the cutoff date used
    def log_data_cleanup(resource_type:, deleted_count:, cutoff:)
      return unless deleted_count.positive?

      Rails.logger.info(
        "[DataCleanup] Deleted #{deleted_count} #{resource_type} older than #{cutoff}"
      )
    end

    # Logs a broadcast error.
    #
    # @param model_name [String] the model class name
    # @param record_id [Integer, String] the record ID
    # @param error [StandardError] the error that occurred
    # @param context [Hash] optional broadcast context (:target, :partial)
    def log_broadcast_error(model_name:, record_id:, error:, context: {})
      backtrace = error.backtrace&.first(5)&.join("\n           ") || "Not available"

      parts = ["[BroadcastError] Model: #{model_name} - Record ID: #{record_id}"]
      parts << "Target: #{context[:target]}" if context[:target]
      parts << "Partial: #{context[:partial]}" if context[:partial]
      parts << "Error: #{error.message}"

      Rails.logger.error(
        "#{parts.join(' - ')}\nBacktrace: #{backtrace}"
      )
    end

    private

    # Formats a context hash for logging.
    #
    # @param context [Hash] the context to format
    # @return [String] formatted context string
    def format_context(context)
      context.map { |k, v| "#{k}=#{v}" }.join(" ")
    end
  end
end
