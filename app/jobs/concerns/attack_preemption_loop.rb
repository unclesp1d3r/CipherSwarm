# frozen_string_literal: true

# REASONING:
#   Why: Both CampaignPriorityRebalanceJob and UpdateStatusJob iterate attacks
#     and attempt preemption with identical per-attack error handling. Extracting
#     this shared loop reduces duplication and ensures consistent behavior.
#   Alternatives Considered:
#     - Inline duplication: simpler but error-prone when updating error handling.
#     - Service object: adds unnecessary indirection for a simple iteration pattern.
#   Decision: ActiveSupport::Concern keeps the logic close to the jobs that use it.
module AttackPreemptionLoop
  extend ActiveSupport::Concern

  private

  # Iterates attacks and attempts preemption for each, with per-attack error isolation.
  #
  # True database connection errors (ConnectionNotEstablished, or StatementInvalid
  # wrapping PG::ConnectionBad/PG::UnableToSend) propagate for Sidekiq retry.
  # All other errors are logged with backtrace and skipped so one failing attack
  # doesn't block others.
  #
  # @param attacks [ActiveRecord::Relation] attacks to evaluate for preemption
  # @return [void]
  def preempt_attacks(attacks)
    attacks.find_each do |attack|
      next if attack.uncracked_count.zero?

      TaskPreemptionService.new(attack).preempt_if_needed
    rescue ActiveRecord::ConnectionNotEstablished
      raise
    rescue ActiveRecord::StatementInvalid => e
      raise if e.cause.is_a?(PG::ConnectionBad) || e.cause.is_a?(PG::UnableToSend)

      Rails.logger.error(
        "[TaskRebalance] SQL error preempting tasks for attack #{attack.id} - " \
        "Error: #{e.class} - #{e.message} - Backtrace: #{Array(e.backtrace).first(5).join(' | ')}"
      )
    rescue StandardError => e
      Rails.logger.error(
        "[TaskRebalance] Error preempting tasks for attack #{attack.id} - " \
        "Error: #{e.class} - #{e.message} - Backtrace: #{Array(e.backtrace).first(5).join(' | ')}"
      )
    end
  end
end
