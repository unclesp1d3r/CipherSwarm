# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# TaskPreemptionService handles intelligent preemption of lower-priority tasks
# when high-priority attacks need to run and all nodes are busy.
#
# This service encapsulates the preemption algorithm, which considers:
# - Available node capacity
# - Task priority (campaign priority)
# - Task progress (avoid preempting nearly-complete tasks)
# - Preemption count (prevent starvation)
#
# @example Basic usage
#   service = TaskPreemptionService.new(high_priority_attack)
#   preempted_task = service.preempt_if_needed
#
class TaskPreemptionService
  # @return [Attack] the attack needing assignment
  attr_reader :attack

  # Initializes a new TaskPreemptionService.
  #
  # @param attack [Attack] the attack that needs a node
  def initialize(attack)
    @attack = attack
  end

  # Preempts a lower-priority task if needed and possible.
  #
  # The preemption algorithm follows this logic:
  # 1. Check if nodes are available (no preemption needed)
  # 2. Find preemptable tasks (lower priority, not near completion, not over-preempted)
  # 3. Select least complete task with lowest priority
  # 4. Abandon the task to return it to pending state
  # 5. Log the preemption event
  #
  # @return [Task, nil] the preempted task, or nil if no preemption occurred
  def preempt_if_needed
    if nodes_available?
      Rails.logger.info(
        "[TaskPreemption] No preemption needed for attack #{attack.id}: nodes available"
      )
      return nil
    end

    preemptable_task = find_preemptable_task
    unless preemptable_task
      Rails.logger.info(
        "[TaskPreemption] No preemptable tasks found for attack #{attack.id} " \
        "(priority: #{attack.campaign.priority})"
      )
      return nil
    end

    preempt_task(preemptable_task)
  end

  private

  # Checks if there are available nodes (active agents > running tasks).
  #
  # @return [Boolean] true if nodes are available
  def nodes_available?
    active_agent_count = Agent.with_state(:active).count
    running_task_count = Task.with_state(:running).count
    active_agent_count > running_task_count
  end

  # Finds the best task to preempt based on priority and progress.
  # Only considers tasks from the same project to prevent cross-project preemption.
  #
  # @return [Task, nil] the task to preempt, or nil if none suitable
  def find_preemptable_task
    # Get all running tasks from lower-priority campaigns in the same project
    priority_value = Campaign.priorities[attack.campaign.priority.to_sym]
    lower_priority_tasks = Task.with_state(:running)
                               .joins(attack: :campaign)
                               .where(campaigns: { project_id: attack.campaign.project_id })
                               # rubocop:disable Rails/WhereRange
                               .where("campaigns.priority < ?", priority_value)
                               # rubocop:enable Rails/WhereRange
                               .includes(attack: :campaign)

    # Filter out tasks that shouldn't be preempted
    preemptable_tasks = lower_priority_tasks.select do |task|
      task.preemptable?
    end

    return nil if preemptable_tasks.empty?

    # Sort by priority (lowest first) then by progress (least complete first)
    preemptable_tasks.min_by do |task|
      [task.attack.campaign.priority, task.progress_percentage]
    end
  end

  # Preempts a task by transitioning it to pending and marking it as stale.
  # Does not destroy the task or trigger attack abandonment.
  # Uses a database transaction with row-level locking to prevent race conditions.
  #
  # We bypass the state machine here and use update_columns because:
  # 1. State machine transitions trigger callbacks that may modify task state (abandon logic)
  # 2. The task object may be stale (optimistic locking conflicts)
  # 3. We need precise control over the transition for preemption semantics
  # 4. We want to avoid N+1 queries from state machine callbacks
  #
  # @param task [Task] the task to preempt
  # @return [Task] the preempted task
  def preempt_task(task)
    Rails.logger.info(
      "[TaskPreemption] Preempting task #{task.id} (priority: #{task.attack.campaign.priority}, " \
      "progress: #{task.progress_percentage}%) for attack #{attack.id} " \
      "(priority: #{attack.campaign.priority})"
    )

    Task.transaction do
      # Lock the task row to prevent concurrent modifications
      task.lock!

      # rubocop:disable Rails/SkipsModelValidations
      task.increment!(:preemption_count)
      # rubocop:enable Rails/SkipsModelValidations

      # Update columns directly to bypass state machine transitions
      # This avoids triggering abandon callbacks and prevents StaleObjectError from optimistic locking
      # rubocop:disable Rails/SkipsModelValidations
      task.update_columns(state: "pending", stale: true)
      # rubocop:enable Rails/SkipsModelValidations
    end

    task
  end
end
