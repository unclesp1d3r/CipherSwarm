# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# REASONING:
#   Why: Tasks require tracking of which agent has claimed them and when the claim expires.
#     The `claimed_by_agent_id` references the agent currently processing the task.
#     `claimed_at` tracks when the claim was established.
#     `expires_at` tracks when the claim becomes invalid (e.g., task timeout on agent).
#   Alternatives Considered:
#     - Store only in Redis: lacks durability and visibility in reports.
#     - Store only in agent state: requires polling agents, not scalable.
#   Decision: Persist in database for visibility, auditing, and recovery.
#   Performance Implications: Minimal; columns are indexed for task reassignment queries.
#   Future Considerations: Claim expiry cleanup could be a background job.
class AddTaskClaimFields < ActiveRecord::Migration[8.0]
  def change
    change_table :tasks, bulk: true do |t|
      t.bigint :claimed_by_agent_id, comment: "Agent currently processing the task"
      t.datetime :claimed_at, comment: "When the agent claimed the task"
      t.datetime :expires_at, comment: "When the task claim expires"

      t.index :claimed_by_agent_id
      t.index :expires_at
      t.index %i[state claimed_by_agent_id]
    end
  end
end
