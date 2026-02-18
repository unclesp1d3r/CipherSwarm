# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# TaskActionsComponent renders action buttons for task management.
#
# Conditionally displays buttons based on task state and user authorization:
# - Cancel: visible when task.pending? || task.running? and user can :cancel
# - Retry: visible when task.failed? and user can :retry
# - Reassign: visible when task.pending? || task.failed? and user can :reassign
# - Logs: always visible (GET request)
# - Download Results: visible when task.completed? || task.exhausted? and user can :download_results
#
# REASONING:
# - Extracted as a ViewComponent to encapsulate action button logic and authorization checks
# - Follows existing patterns in the codebase (StatusPillComponent, CampaignProgressComponent)
# - Keeps the view template clean by moving conditional rendering logic to the component
# - Makes testing easier through isolated component specs
#
# == Options
# - task: (Task, required) The task model instance
# - current_ability: (Ability, required) The CanCanCan ability instance for authorization
#
# == Example
#   render(TaskActionsComponent.new(task: @task, current_ability: current_ability))
class TaskActionsComponent < ApplicationViewComponent
  include BootstrapIconHelper

  option :task, required: true
  option :current_ability, required: true

  # Returns true if the cancel button should be displayed.
  # Task can be cancelled when pending or running, and user has :cancel permission.
  #
  # @return [Boolean]
  def can_cancel?
    (@task.pending? || @task.running?) && @current_ability.can?(:cancel, @task)
  end

  # Returns true if the retry button should be displayed.
  # Task can be retried when failed, and user has :retry permission.
  #
  # @return [Boolean]
  def can_retry?
    @task.failed? && @current_ability.can?(:retry, @task)
  end

  # Returns true if the reassign button should be displayed.
  # Task can be reassigned when pending or failed, and user has :reassign permission.
  #
  # @return [Boolean]
  def can_reassign?
    # Task can be reassigned when pending, running, failed, or paused (matches controller logic)
    (@task.pending? || @task.running? || @task.failed? || @task.paused?) && @current_ability.can?(:reassign, @task)
  end

  # Returns true if the download results button should be displayed.
  # Only visible for completed or exhausted tasks when user has :download_results permission.
  #
  # @return [Boolean]
  def can_download_results?
    (@task.completed? || @task.exhausted?) && @current_ability.can?(:download_results, @task)
  end

  # Returns agents that are compatible with the task's project.
  # Used for the reassign agent dropdown.
  #
  # @return [ActiveRecord::Relation<Agent>] compatible agents
  def compatible_agents
    @compatible_agents ||= begin
      project = @task.attack&.campaign&.project
      if project
        # Agents with no projects (global) or assigned to this project
        Agent.left_joins(:projects)
             .where("agents_projects.project_id IS NULL OR agents_projects.project_id = ?", project.id)
             .where.not(id: @task.agent_id)
             .where(enabled: true)
             .distinct
             .order(:host_name)
      else
        Agent.none
      end
    end
  end

  # URL helpers
  def cancel_path
    cancel_task_path(@task)
  end

  def retry_path
    retry_task_path(@task)
  end

  def reassign_path
    reassign_task_path(@task)
  end

  def logs_path
    logs_task_path(@task)
  end

  def download_results_path
    download_results_task_path(@task)
  end
end
