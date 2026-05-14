# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Broadcasts a debounced "recent cracks" Turbo Stream update for a campaign.
#
# Enqueued by HashItem#broadcast_recent_cracks_update once per
# (hash_list_id, campaign_id) per debounce window to cap Action Cable traffic
# on high-rate crack streams (e.g., ~25 RTX 4090s sustaining thousands of
# cracks per second across multiple campaigns).
class BroadcastRecentCracksJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  # @param campaign_id [Integer] the campaign whose recent_cracks panel should refresh
  # @return [void]
  def perform(campaign_id)
    Campaign.find(campaign_id).broadcast_recent_cracks_update
  end
end
