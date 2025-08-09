# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class RemoveIndexAttacksOnCampaignIdIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index nil, name: "index_attacks_on_campaign_id"
  end
end
