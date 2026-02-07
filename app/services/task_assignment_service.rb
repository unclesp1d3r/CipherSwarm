# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# TaskAssignmentService handles the complex logic of finding and assigning
# the next appropriate task to an agent.
#
# This service encapsulates the task assignment algorithm, which considers:
# - Incomplete tasks already assigned to the agent
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
  # 2. Searches for failed tasks that can be retried
  # 3. Returns pending tasks from existing attacks
  # 4. Creates a new task for attacks without pending tasks
  #
  # @return [Task, nil] the next task to work on, or nil if no tasks are available
  def find_next_task
    find_existing_incomplete_task ||
      find_task_from_available_attacks
  end

  private

  # Finds an existing incomplete task assigned to the agent.
  #
  # @return [Task, nil] an incomplete task without fatal errors, or nil
  def find_existing_incomplete_task
    agent.tasks.incomplete.find do |task|
      !has_fatal_error?(task) && task.uncracked_remaining
    end
  end

  # Searches available attacks for a task to assign.
  #
  # This method is the core of the priority-based scheduling system:
  # 1. Iterates attacks in priority order (high → normal → deferred)
  # 2. For each attack, tries to find/create a task
  # 3. If no task available and attack is high priority, attempts preemption
  # 4. Preemption allows high-priority work to interrupt lower-priority tasks
  #
  ##
  # Searches the agent's available attacks in priority order and returns the first assignable task.
  # May attempt preemption on higher-priority attacks when no immediate task is found, and will retry after successful preemption.
  # @return [Task, nil] The found or newly created task for the agent, or `nil` if no task could be assigned.
  def find_task_from_available_attacks
    return nil if agent.project_ids.blank?

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

  # Checks if preemption should be attempted for an attack.
  #
  # Preemption is only considered for normal and high priority attacks.
  # Deferred attacks wait naturally and never trigger preemption.
  #
  # The defensive nil checks and error handling ensure the assignment
  # process continues even if campaign data is malformed or missing.
  #
  # @param attack [Attack] the attack to check
  ##
  # Determines whether preemption should be attempted for the given attack.
  # @param [Attack] attack - The attack to evaluate; may be nil.
  # @return [Boolean] `true` if the attack's campaign exists and its priority is not `:deferred` (for example normal or high), `false` otherwise or on error.
  def should_attempt_preemption?(attack)
    # Only attempt preemption for normal or high priority attacks
    # Deferred attacks wait naturally
    return false if attack.nil? || attack.campaign.nil?

    attack.campaign.priority.present? && attack.campaign.priority.to_sym != :deferred
  rescue StandardError => e
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
    attack.tasks.with_state(:failed).where(agent: agent).find do |task|
      !has_fatal_error?(task)
    end
  end

  # Finds an existing pending task.
  #
  # @param attack [Attack] the attack to search in
  # @return [Task, nil] a pending task, or nil
  def find_pending_task(attack)
    attack.tasks.with_state(:pending).where(agent: agent).first
  end

  # Creates a new task if the agent meets performance requirements and no pending tasks exist.
  #
  # @param attack [Attack] the attack to create a task for
  # @return [Task, nil] the newly created task, or nil if requirements not met
  def create_new_task_if_eligible(attack)
    return nil if attack.tasks.with_state(:pending).any?

    if agent.meets_performance_threshold?(attack.hash_mode)
      agent.tasks.create(attack: attack, start_date: Time.zone.now)
    else
      log_performance_skip(attack)
      nil
    end
  end

  # Checks if the agent has a fatal error for a specific task.
  #
  # @param task [Task] the task to check
  # @return [Boolean] true if there's a fatal error for this task
  def has_fatal_error?(task)
    agent.agent_errors.exists?(severity: :fatal, task_id: task.id)
  end

  # Returns attacks available for the agent based on projects and hash types.
  #
  # Ordering strategy:
  # 1. campaigns.priority DESC: High priority attacks first (high=2, normal=0, deferred=-1)
  # 2. attacks.complexity_value: Within same priority, simpler attacks first
  # 3. attacks.created_at: Tie-breaker for same priority and complexity
  #
  # This ordering ensures high-priority campaigns get resources first,
  # while still respecting attack complexity within each priority level.
  #
  ##
  # Retrieves attacks that are not complete for campaigns associated with the agent, filtered by the agent's allowed hash types and ordered by campaign priority, attack complexity, then creation time.
  # @return [ActiveRecord::Relation<Attack>] An ActiveRecord relation of matching Attack records ordered by campaigns.priority DESC, attacks.complexity_value, and attacks.created_at.
  def available_attacks
    Attack.incomplete
          .joins(campaign: { hash_list: :hash_type })
          .includes(campaign: %i[hash_list project])
          .where(campaigns: { project_id: agent.project_ids })
          .where(hash_lists: { hash_type_id: allowed_hash_type_ids })
          .order("campaigns.priority DESC, attacks.complexity_value, attacks.created_at")
  end

  # Returns hash type IDs the agent can work on, cached for performance.
  #
  # @return [Array<Integer>] array of allowed hash type IDs
  def allowed_hash_type_ids
    Rails.cache.fetch("#{agent.cache_key_with_version}/allowed_hash_types", expires_in: 1.hour) do
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
