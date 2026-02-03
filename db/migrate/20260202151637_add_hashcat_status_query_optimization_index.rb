# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Adds composite index to optimize the frequently-called Task#latest_status query:
#   hashcat_statuses.where(status: :running).order(time: :desc).first
#
# This index allows PostgreSQL to use an index-only scan for this common query pattern,
# reducing query time from full table scan to indexed lookup.
class AddHashcatStatusQueryOptimizationIndex < ActiveRecord::Migration[8.0]
  def change
    # Composite index for Task#latest_status query optimization
    # Query pattern: WHERE task_id = ? AND status = ? ORDER BY time DESC LIMIT 1
    add_index :hashcat_statuses, %i[task_id status time],
              name: "index_hashcat_statuses_on_task_status_time",
              order: { time: :desc }
  end
end
