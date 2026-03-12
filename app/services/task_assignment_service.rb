# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# TaskAssignmentService handles the complex logic of finding and assigning
# the next appropriate task to an agent.
#
# This service encapsulates the task assignment algorithm, which considers:
# - Incomplete tasks already assigned to the agent
# - Agent's own paused tasks (for restore file reuse after restart)
# - Orphaned paused tasks from offline/stopped agents (grace period)
# - Agent's project membership
# - Supported hash types based on benchmarks
# - Attack complexity ordering
# - Performance thresholds
#
# @example Basic usage
#   service = TaskAssignmentService.new(agent)
#   task = service.find_next_task
#
class TaskAssignmentService
  # @return [Agent] the agent to assign a task to
  attr_reader :agent

  # Initializes a new TaskAssignmentService.
  #
  # @param agent [Agent] the agent requesting a new task
  def initialize(agent)
    @agent = agent
  end

  # Finds and returns the next available task for the agent.
  #
  # The assignment algorithm follows this priority:
  # 1. Returns any incomplete task already assigned to the agent (without fatal errors)
  # 2. Reclaims the agent's own paused tasks (e.g. after restart, to use restore files)
  # 3. Claims orphaned paused tasks from other agents (after grace period)
  # 4. Searches for failed tasks that can be retried
  # 5. Returns pending tasks from existing attacks
  # 6. Creates a new task for attacks without pending tasks
  #
  # @return [Task, nil] the next task to work on, or nil if no tasks are available
  def find_next_task
    find_existing_incomplete_task ||
      find_own_paused_task ||
      find_unassigned_paused_task ||
      find_task_from_available_attacks
  end

  private

  # Finds an existing incomplete task assigned to the agent.
  #
  # REASONING:
  # - Uses NOT EXISTS subquery to filter tasks with fatal errors in a single SQL query
  #   rather than iterating tasks and issuing one EXISTS query per task.
  # - Uses EXISTS to confirm uncracked hash items remain, avoiding join row multiplication.
  # - Alternatives: INNER JOIN + DISTINCT (bloated result set), LEFT JOIN + WHERE NOT NULL
  #   (less readable), Ruby iteration (N+1 queries on large task sets).
  # - Decision: EXISTS subqueries are index-friendly, avoid duplicates, and push filtering to DB.
  #
  # @return [Task, nil] an incomplete task without fatal errors, or nil
  def find_existing_incomplete_task
    agent.tasks.incomplete
         .where.not(id: AgentError.where(agent: agent, severity: :fatal).select(:task_id))
         .joins(attack: { campaign: :hash_list })
         .where("EXISTS (SELECT 1 FROM hash_items WHERE hash_items.hash_list_id = hash_lists.id AND hash_items.cracked = false)")
         .order(:id)
         .first
  end

  # Reclaims the agent's own paused tasks after a restart.
  #
  # REASONING:
  # - When an agent shuts down, its running tasks are paused and claim fields cleared.
  # - On restart, the agent should reclaim its own paused tasks first to leverage
  #   restore files and avoid redundant work.
  # - No FOR UPDATE SKIP LOCKED needed because agent.tasks already scopes to this
  #   agent's agent_id, so no cross-agent race is possible.
  # - Only returns tasks where uncracked hashes remain to avoid wasted work.
  #
  # @return [Task, nil] the agent's own paused task (transitioned to pending), or nil
  def find_own_paused_task
    task = agent.tasks.with_state(:paused)
                .where(claimed_by_agent_id: [nil, agent.id])
                .joins(attack: { campaign: :hash_list })
                .where("EXISTS (SELECT 1 FROM hash_items WHERE hash_items.hash_list_id = hash_lists.id AND hash_items.cracked = false)")
                .order(:id)
                .first

    return nil unless task

    if task.attack.paused? && task.attack.can_resume?
      task.attack.resume!
      task.reload # attack.resume_tasks may have already resumed this task
    end
    task.resume! if task.paused? && task.can_resume?
    task
  rescue StateMachines::InvalidTransition, ActiveRecord::StaleObjectError => e
    Rails.logger.error(
      "[TaskAssignmentService] Failed to resume own paused task #{task.id} " \
      "for agent #{agent.id}: #{e.class} - #{e.message}"
    )
    nil
  end

  # Finds an orphaned paused task from another agent that this agent can work on.
  #
  # REASONING:
  # - When agents shut down, their running tasks are paused and claim fields are cleared.
  # - agent_id remains populated (NOT NULL column) pointing to the original agent.
  # - This method discovers orphaned tasks using a time-based grace period (paused_at)
  #   instead of checking the owning agent's state. This ensures tasks become available
  #   even if the original agent restarts but doesn't reclaim the task.
  # - The grace period (agent_considered_offline_time, default 30 min) gives the original
  #   agent time to reclaim its own tasks via find_own_paused_task.
  # - Tasks from offline/stopped agents are available immediately (no grace period).
  # - tasks.paused_at IS NULL covers legacy paused tasks created before the paused_at
  #   column was added — these are treated as immediately available since their pause
  #   time is unknown.
  # - Scoped to the claiming agent's projects and supported hash types for authorization.
  # - Only returns tasks where uncracked hashes remain to avoid wasted work.
  # - On pickup, agent_id is reassigned to the claiming agent within this method.
  # - Uses FOR UPDATE SKIP LOCKED to prevent two agents from racing to claim the same task.
  #
  # @return [Task, nil] a reassigned paused task, or nil
  def find_unassigned_paused_task
    task = nil

    Task.transaction do
      scope = Task.with_state(:paused)
                   .where(claimed_by_agent_id: nil)
                   .where.not(agent_id: agent.id)
                   .joins(:agent)
                   .where(
                     "tasks.paused_at IS NULL OR tasks.paused_at < :grace_cutoff OR agents.state IN (:orphan_states)",
                     grace_cutoff: ApplicationConfig.agent_considered_offline_time.ago,
                     orphan_states: %w[offline stopped]
                   )
                   .joins(attack: { campaign: :hash_list })
                   .where(hash_lists: { hash_type_id: allowed_hash_type_ids })

      scope = scope.where(campaigns: { project_id: agent.project_ids }) if agent.project_ids.present?

      task = scope
                 .where("EXISTS (SELECT 1 FROM hash_items WHERE hash_items.hash_list_id = hash_lists.id AND hash_items.cracked = false)")
                 .order(:id)
                 .lock("FOR UPDATE OF tasks SKIP LOCKED")
                 .first

      return nil unless task

      # Reassign ownership to the claiming agent
      # rubocop:disable Rails/SkipsModelValidations
      task.update_columns(agent_id: agent.id)
      # rubocop:enable Rails/SkipsModelValidations

      # Resume the attack if it was paused (e.g., due to agent shutdown cascade).
      # Note: there is no programmatic distinction between shutdown-paused and
      # campaign-paused attacks; the can_resume? guard prevents invalid transitions.
      # Wrapped in rescue so ownership reassignment above is preserved even if resume fails.
      # Next cycle's find_own_paused_task will retry the resume.
      begin
        if task.attack.paused? && task.attack.can_resume?
          task.attack.resume!
          task.reload # attack.resume_tasks may have already resumed this task
        end

        # Transition to pending so the new agent can accept the task.
        # resume! moves paused -> pending, marks stale (so the agent re-downloads cracks),
        # and clears paused_at (removing the task from grace period queries).
        task.resume! if task.paused? && task.can_resume?
      rescue StateMachines::InvalidTransition, ActiveRecord::StaleObjectError => e
        Rails.logger.error(
          "[TaskAssignmentService] Failed to resume orphaned task #{task.id} " \
          "for agent #{agent.id}: #{e.class} - #{e.message}"
        )
        # Ownership was reassigned; task stays paused but belongs to the new agent.
        # Next cycle's find_own_paused_task will pick it up.
      end
    end

    task
  end

  # Searches available attacks in priority order and returns the first assignable task.
  #
  # This method is the core of the priority-based scheduling system:
  # 1. Iterates attacks in campaign priority order (high → normal → deferred)
  # 2. For each attack, tries to find/create a task
  # 3. If no task available and campaign priority is not deferred, attempts preemption
  # 4. Preemption allows high-priority work to interrupt lower-priority tasks
  #
  # @return [Task, nil] the found or newly created task, or nil if none available
  def find_task_from_available_attacks
    available_attacks.each do |attack|
      next if attack.uncracked_count.zero?

      task = find_or_create_task_for_attack(attack)
      return task if task

      # If no task was found and this is a higher-priority attack, try preemption
      if should_attempt_preemption?(attack)
        begin
          preempted = TaskPreemptionService.new(attack).preempt_if_needed
          if preempted
            # Retry finding/creating a task after successful preemption
            task = find_or_create_task_for_attack(attack)
            return task if task
          end
        rescue StandardError => e
          Rails.logger.error(
            "[TaskAssignmentService] Preemption failed for attack #{attack.id}: " \
            "#{e.class} - #{e.message}"
          )
          # Continue to next attack if preemption fails
        end
      end
    end

    nil
  end

  # Determines whether preemption should be attempted for the given attack.
  #
  # Preemption is attempted for any campaign priority except :deferred.
  # Deferred attacks wait naturally and never trigger preemption.
  # Defensive nil checks ensure the assignment process continues
  # even if campaign data is malformed or missing.
  #
  # @param attack [Attack] the attack to evaluate; may be nil
  # @return [Boolean] true if campaign priority is not :deferred, false otherwise or on error
  def should_attempt_preemption?(attack)
    # Only attempt preemption for normal or high priority attacks
    # Deferred attacks wait naturally
    return false if attack.nil? || attack.campaign.nil?

    attack.campaign.priority.present? && attack.campaign.priority.to_sym != :deferred
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error(
      "[TaskAssignmentService] Error checking preemption eligibility for attack #{attack&.id} - " \
      "Error: #{e.class} - #{e.message} - #{Time.current}"
    )
    false
  end

  # Finds or creates a task for a specific attack.
  #
  # @param attack [Attack] the attack to find or create a task for
  # @return [Task, nil] a task for the attack, or nil if none available
  def find_or_create_task_for_attack(attack)
    find_retryable_failed_task(attack) ||
      find_pending_task(attack) ||
      create_new_task_if_eligible(attack)
  end

  # Finds a failed task that can be retried (no fatal errors).
  #
  # @param attack [Attack] the attack to search in
  # @return [Task, nil] a retryable failed task, or nil
  def find_retryable_failed_task(attack)
    attack.tasks.with_state(:failed)
         .where(agent: agent)
         .where.not(id: AgentError.where(agent: agent, severity: :fatal).select(:task_id))
         .order(:id)
         .first
  end

  # Finds an existing pending task.
  #
  # @param attack [Attack] the attack to search in
  # @return [Task, nil] a pending task, or nil
  def find_pending_task(attack)
    attack.tasks.with_state(:pending).where(agent: agent).order(:id).first
  end

  # Creates a new task if the agent meets performance requirements and no pending tasks exist.
  # Uses a row lock on the attack to prevent two agents from creating duplicate tasks.
  #
  # @param attack [Attack] the attack to create a task for
  # @return [Task, nil] the newly created task, or nil if requirements not met
  def create_new_task_if_eligible(attack)
    unless agent.meets_performance_threshold?(attack.hash_mode)
      log_performance_skip(attack)
      return nil
    end

    Task.transaction do
      # Lock the attack row to serialize task creation per attack
      attack.lock!
      return nil if attack.tasks.with_state(:pending).any?

      agent.tasks.create(attack: attack, start_date: Time.zone.now)
    end
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.error(
      "[TaskAssignmentService] Error creating task for attack #{attack.id}: " \
      "#{e.class} - #{e.message}"
    )
    nil
  end

  # Returns attacks available for the agent based on projects and hash types.
  #
  # Agents with no project assignments can work on any project (same convention
  # as attack resources like word lists, rule lists, and Task#agent_compatible?).
  #
  # Ordering strategy:
  # 1. campaigns.priority DESC: Higher campaign priority first (high=2, normal=0, deferred=-1)
  # 2. attacks.complexity_value: Within same priority, simpler attacks first
  # 3. attacks.created_at: Tie-breaker for same priority and complexity
  #
  # @return [ActiveRecord::Relation<Attack>] attacks ordered by campaign priority, complexity, creation time
  def available_attacks
    scope = Attack.incomplete
                  .joins(campaign: { hash_list: :hash_type })
                  .includes(campaign: %i[hash_list project])
                  .where(hash_lists: { hash_type_id: allowed_hash_type_ids })

    scope = scope.where(campaigns: { project_id: agent.project_ids }) if agent.project_ids.present?

    scope.order("campaigns.priority DESC, attacks.complexity_value, attacks.created_at")
  end

  # Returns hash type IDs the agent can work on, cached for performance.
  #
  # @return [Array<Integer>] array of allowed hash type IDs
  def allowed_hash_type_ids
    @allowed_hash_type_ids ||= Rails.cache.fetch("#{agent.cache_key_with_version}/allowed_hash_types", expires_in: 1.hour) do
      HashType.where(hashcat_mode: agent.allowed_hash_types).pluck(:id)
    end
  end

  # Logs an info-level agent error when a task is skipped due to performance threshold.
  #
  # @param attack [Attack] the attack that was skipped
  # @return [AgentError] the created error record
  def log_performance_skip(attack)
    agent.agent_errors.create(
      severity: :info,
      message: "Task skipped for agent because it does not meet the performance threshold",
      metadata: { attack_id: attack.id, hash_type: attack.hash_type }
    )
  end
end
