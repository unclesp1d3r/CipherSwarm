# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddAttacksCampaignIdIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :attacks, :campaign_id, name: :index_attacks_campaign_id
  end
end
