# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# TaskPreemptionService handles intelligent preemption of lower-priority tasks
# when higher-priority attacks need to run and all nodes are busy.
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

  # Initializes the service with the attack that requires a node.
  #
  # @param attack [Attack] the attack instance requiring a node
  def initialize(attack)
    @attack = attack
  end

  # Decides whether a node must be freed for the service's attack and, if required,
  # selects and preempts a running task from a lower-priority campaign.
  #
  # The preemption algorithm:
  # 1. Check if nodes are available (no preemption needed)
  # 2. Find preemptable tasks (lower priority, not near completion, not over-preempted)
  # 3. Select least complete task with lowest priority
  # 4. Preempt the task (transition to pending, mark stale, increment preemption count)
  #
  # @return [Task, nil] The preempted task if one was preempted, `nil` otherwise.
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

  # Determines whether there are more active agents assigned to the project than
  # running tasks for that project. Scoped to the project to match find_preemptable_task filtering.
  #
  # @return [Boolean] true if there are more active agents than running tasks
  def nodes_available?
    project_id = attack.campaign.project_id
    active_agent_count = Agent.joins(:projects)
                              .where(projects: { id: project_id })
                              .with_state(:active)
                              .distinct
                              .count
    running_task_count = Task.joins(attack: :campaign)
                             .where(campaigns: { project_id: project_id })
                             .with_state(:running)
                             .count
    active_agent_count > running_task_count
  end

  # Selects a running task from a lower-priority campaign in the same project that can be preempted.
  #
  # The chosen task must belong to a campaign with a strictly lower priority than the current
  # attack's campaign and respond true to `preemptable?`. When multiple candidates exist, the
  # task with the lowest campaign priority and then the smallest progress percentage (least
  # complete) is returned. Returns `nil` when no suitable task is found.
  #
  # Per-candidate errors during `preemptable?` checks are logged and the candidate is skipped;
  # if all evaluated candidates error, a warning is logged. Unexpected errors from the outer
  # query or sorting are re-raised for the caller (AttackPreemptionLoop) to handle.
  #
  # @return [Task, nil] The task to preempt, or `nil` if none suitable.
  # @raise [StandardError] if the query or sorting raises unexpectedly
  def find_preemptable_task
    # Get all running tasks from lower-priority campaigns in the same project.
    # Pre-filter preemption_count in SQL to avoid loading tasks that can never be preempted.
    priority_value = Campaign.priorities[attack.campaign.priority.to_sym]
    lower_priority_tasks = Task.with_state(:running)
                               .joins(attack: :campaign)
                               .where(campaigns: { project_id: attack.campaign.project_id })
                               # rubocop:disable Rails/WhereRange
                               .where("campaigns.priority < ?", priority_value)
                               # rubocop:enable Rails/WhereRange
                               .where(preemption_count: 0..1)
                               .includes(attack: :campaign)
                               .includes(:hashcat_statuses)

    # Filter out tasks that shouldn't be preempted
    error_count = 0
    preemptable_tasks = lower_priority_tasks.select do |task|
      task.preemptable?
    rescue StandardError => e
      error_count += 1
      Rails.logger.error(
        "[TaskPreemption] Error checking if task #{task.id} is preemptable: " \
        "#{e.message} - Backtrace: #{Array(e.backtrace).first(5).join(' | ')}"
      )
      false
    end

    if preemptable_tasks.empty? && error_count.positive?
      Rails.logger.warn(
        "[TaskPreemption] No preemptable tasks found for attack #{attack.id}; " \
        "#{error_count} of #{lower_priority_tasks.size} candidate(s) raised errors during preemptable? check"
      )
    end

    return nil if preemptable_tasks.empty?

    # Sort by priority (lowest first, using numeric enum value) then by progress (least complete first)
    # Use task id as tiebreaker for deterministic selection when priority and progress are equal
    preemptable_tasks.min_by do |task|
      [task.attack.campaign[:priority], task.progress_percentage, task.id]
    end
  rescue StandardError
    raise # Let the per-attack rescue in AttackPreemptionLoop handle with proper context
  end

  # Preempts a task using the dedicated preempt state machine event.
  # The preempt event transitions running -> pending without triggering attack abandon.
  # The after_transition callback handles marking as stale and incrementing preemption_count.
  # Uses a database transaction with row-level locking to prevent race conditions.
  #
  # Handles the race condition where concurrent jobs (CampaignPriorityRebalanceJob and
  # UpdateStatusJob) may try to preempt the same task simultaneously. If the task has
  # already transitioned away from running, the preemption is skipped gracefully.
  #
  # @param task [Task] the task to preempt
  # @return [Task, nil] The preempted task, or nil if already transitioned
  def preempt_task(task)
    Rails.logger.info(
      "[TaskPreemption] Preempting task #{task.id} (priority: #{task.attack.campaign.priority}, " \
      "progress: #{task.progress_percentage}%) for attack #{attack.id} " \
      "(priority: #{attack.campaign.priority})"
    )

    Task.transaction do
      task.lock!
      unless task.running?
        Rails.logger.info(
          "[TaskPreemption] Task #{task.id} already transitioned to #{task.state} " \
          "(likely preempted by concurrent job), skipping"
        )
        return nil
      end
      task.preempt!
    end

    task
  end
end
