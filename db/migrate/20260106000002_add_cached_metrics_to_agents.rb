# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddCachedMetricsToAgents < ActiveRecord::Migration[7.2]
  def change
    change_table :agents, bulk: true do |t|
      t.decimal :current_hash_rate, precision: 20, scale: 2, default: 0,
                                    comment: "Current hash rate in H/s, updated from HashcatStatus"
      t.integer :current_temperature, default: 0,
                                      comment: "Current device temperature in Celsius, updated from HashcatStatus"
      t.integer :current_utilization, default: 0,
                                      comment: "Current device utilization percentage, updated from HashcatStatus"
      t.datetime :metrics_updated_at,
                 comment: "Timestamp of last metrics update for throttling"
      t.index [:metrics_updated_at], name: "index_agents_on_metrics_updated_at"
    end
  end
end
