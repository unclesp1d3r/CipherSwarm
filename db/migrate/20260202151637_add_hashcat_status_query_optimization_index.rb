# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Adds composite index to optimize the frequently-called Task#latest_status query:
#   hashcat_statuses.where(status: :running).order(time: :desc).first
#
# This index allows PostgreSQL to use an index-only scan for this common query pattern,
# reducing query time from full table scan to indexed lookup.
#
# REASONING:
# - Why: Task#latest_status is called frequently (status updates, progress display) and
#   performs a filtered, ordered lookup on hashcat_statuses. Without an index, PostgreSQL
#   must scan all statuses for a task and sort them.
# - Alternatives considered:
#   1. Single-column index on task_id: insufficient for status/time filtering
#   2. Separate indexes on each column: less efficient than composite for this query pattern
#   3. Materialized view with cached latest status: adds complexity and cache invalidation risk
# - Decision: Use composite index (task_id, status, time DESC) matching the query shape.
#   This allows index-only scans and avoids additional table lookups.
# - Performance: Reduces query time from O(n) table scan to O(log n) index lookup.
# - Future: Revisit if query patterns change or if the index becomes too large.
class AddHashcatStatusQueryOptimizationIndex < ActiveRecord::Migration[8.0]
  def change
    # Composite index for Task#latest_status query optimization
    # Query pattern: WHERE task_id = ? AND status = ? ORDER BY time DESC LIMIT 1
    add_index :hashcat_statuses, %i[task_id status time],
              name: "index_hashcat_statuses_on_task_status_time",
              order: { time: :desc }
  end
end
