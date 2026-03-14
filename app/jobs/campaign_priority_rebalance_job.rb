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
  include AttackPreemptionLoop

  queue_as :high
  discard_on ActiveRecord::RecordNotFound

  # Performs task preemption evaluation for all incomplete attacks in the campaign.
  #
  # NOTE: Each call to TaskPreemptionService#preempt_if_needed runs at least 2 COUNT
  # queries via nodes_available?, plus additional queries if preemption candidates must
  # be evaluated. This is acceptable because campaigns typically have a small number of
  # attacks (single digits), so the overhead is negligible.
  #
  # @param campaign_id [Integer] the ID of the Campaign whose priority was raised
  # @return [void]
  def perform(campaign_id)
    campaign = Campaign.find(campaign_id)

    attacks = campaign.attacks.incomplete
                      .includes(campaign: :hash_list)

    preempt_attacks(attacks)
  end
end
