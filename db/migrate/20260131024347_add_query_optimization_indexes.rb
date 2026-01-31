# frozen_string_literal: true

# Adds database indexes to optimize common query patterns in task assignment
# and campaign management workflows.
class AddQueryOptimizationIndexes < ActiveRecord::Migration[8.0]
  def change
    # Index for ORDER BY campaigns.priority DESC in TaskAssignmentService
    add_index :campaigns, :priority

    # Composite index for finding attacks by state within a campaign
    # Used when querying attacks with specific states for a campaign
    add_index :attacks, %i[campaign_id state], name: "index_attacks_on_campaign_id_and_state"

    # Composite index for project-based campaign queries with priority ordering
    # Optimizes: WHERE campaigns.project_id IN (...) ORDER BY priority DESC
    add_index :campaigns, %i[project_id priority], name: "index_campaigns_on_project_id_and_priority"
  end
end
