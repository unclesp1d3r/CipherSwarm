# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Triggers task preemption for a campaign whose priority was raised.
#
# When a campaign's priority increases, lower-priority tasks running on agents
# may need to be preempted so the higher-priority campaign's attacks can run.
# This job iterates through the campaign's incomplete attacks and delegates
# preemption decisions to TaskPreemptionService.
#
# Enqueued by Campaign#trigger_priority_rebalance_if_needed after_commit callback.
class CampaignPriorityRebalanceJob < ApplicationJob
  queue_as :high
  discard_on ActiveRecord::RecordNotFound

  # Performs task preemption evaluation for all incomplete attacks in the campaign.
  #
  # @param campaign_id [Integer] the ID of the Campaign whose priority was raised
  # @return [void]
  def perform(campaign_id)
    campaign = Campaign.find(campaign_id)

    attacks = campaign.attacks.incomplete
                      .includes(:campaign, campaign: :hash_list)

    attacks.each do |attack|
      begin
        next if attack.uncracked_count.zero?

        TaskPreemptionService.new(attack).preempt_if_needed
      rescue StandardError => e
        Rails.logger.error(
          "[TaskRebalance] Error preempting tasks for attack #{attack.id} - " \
          "Error: #{e.class} - #{e.message} - Backtrace: #{e.backtrace&.first(5)&.join(' | ')}"
        )
        # Continue with next attack
      end
    end
  end
end
