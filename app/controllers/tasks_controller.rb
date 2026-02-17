# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Controller for managing Task resources.
#
# The TasksController handles actions related to viewing and managing tasks
# assigned to agents. Tasks represent individual units of work within an attack.
#
# Filters:
# - `before_action :authenticate_user!` ensures that only authenticated users access controller actions.
# - `before_action :set_task` loads the task for actions.
class TasksController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!
  before_action :set_task

  # POST /tasks/:id/cancel
  # Cancels a pending or running task, transitioning it to failed state.
  def cancel
    authorize! :cancel, @task

    if @task.cancel
      Rails.logger.info("[TaskAction] Task #{@task.id} cancelled by user #{current_user.id}")
      respond_to do |format|
        format.html { redirect_to @task, notice: "Task was successfully cancelled." }
        format.turbo_stream { render turbo_stream: task_turbo_streams(message: "Task was successfully cancelled.", variant: "success") }
      end
    else
      Rails.logger.warn("[TaskAction] Task #{@task.id} could not be cancelled - current state: #{@task.state}")
      respond_to do |format|
        format.html { redirect_to @task, alert: "Task could not be cancelled. Only pending or running tasks can be cancelled." }
        format.turbo_stream { render turbo_stream: task_turbo_streams(message: "Task could not be cancelled. Only pending or running tasks can be cancelled.", variant: "danger") }
      end
    end
  end

  # POST /tasks/:id/retry
  # Retries a failed task, transitioning it back to pending state.
  # The retry event increments retry_count and clears last_error.
  def retry
    authorize! :retry, @task

    if @task.retry
      Rails.logger.info("[TaskAction] Task #{@task.id} retried by user #{current_user.id} - retry count: #{@task.retry_count}")
      respond_to do |format|
        format.html { redirect_to @task, notice: "Task was successfully queued for retry." }
        format.turbo_stream { render turbo_stream: task_turbo_streams(message: "Task was successfully queued for retry.", variant: "success") }
      end
    else
      Rails.logger.warn("[TaskAction] Task #{@task.id} could not be retried - current state: #{@task.state}")
      respond_to do |format|
        format.html { redirect_to @task, alert: "Task could not be retried. Only failed tasks can be retried." }
        format.turbo_stream { render turbo_stream: task_turbo_streams(message: "Task could not be retried. Only failed tasks can be retried.", variant: "danger") }
      end
    end
  end

  # GET /tasks/:id/logs
  # Displays paginated hashcat status history for a task.
  def logs
    authorize! :read, @task
    @pagy, @statuses = pagy(
      @task.hashcat_statuses.order(time: :desc),
      limit: 50
    )
  end

  # GET /tasks/1 or /tasks/1.json
  def show
    authorize! :read, @task
  end

  # POST /tasks/:id/reassign
  # Reassigns a task to a different agent.
  # Validates agent compatibility before reassignment.
  # For running tasks, abandons the task (resets to pending) before reassigning.
  def reassign
    authorize! :reassign, @task

    # Validate agent_id parameter
    if params[:agent_id].blank?
      respond_to do |format|
        format.html { redirect_to @task, alert: "Please select an agent for reassignment." }
        format.turbo_stream { render turbo_stream: task_turbo_streams(message: "Please select an agent for reassignment.", variant: "danger") }
      end
      return
    end

    new_agent = Agent.find(params[:agent_id])

    # Validate task can be reassigned (not completed or exhausted)
    unless @task.pending? || @task.running? || @task.failed? || @task.paused?
      respond_to do |format|
        format.html { redirect_to @task, alert: "Task cannot be reassigned. Only pending, running, failed, or paused tasks can be reassigned." }
        format.turbo_stream { render turbo_stream: task_turbo_streams(message: "Task cannot be reassigned. Only pending, running, failed, or paused tasks can be reassigned.", variant: "danger") }
      end
      return
    end

    # Validate agent compatibility
    unless @task.compatible_agent?(new_agent)
      Rails.logger.warn("[TaskAction] Task #{@task.id} reassignment denied - Agent #{new_agent.id} not compatible with project")
      respond_to do |format|
        format.html { redirect_to @task, alert: "Agent is not compatible with this task's project. The agent must have access to the project." }
        format.turbo_stream { render turbo_stream: task_turbo_streams(message: "Agent is not compatible with this task's project. The agent must have access to the project.", variant: "danger") }
      end
      return
    end

    # If task is running, pause it then resume to reset to pending
    # Note: We don't use abandon here because abandon triggers attack.abandon which destroys all tasks
    if @task.running?
      @task.pause if @task.can_pause?
      @task.resume if @task.can_resume?
      @task.update_columns(stale: true) # rubocop:disable Rails/SkipsModelValidations
    end

    # Reassign the task to the new agent
    if @task.update(agent: new_agent)
      Rails.logger.info("[TaskAction] Task #{@task.id} reassigned from agent #{@task.agent_id_before_last_save} to agent #{new_agent.id} by user #{current_user.id}")
      respond_to do |format|
        format.html { redirect_to @task, notice: "Task was successfully reassigned." }
        format.turbo_stream { render turbo_stream: task_turbo_streams(message: "Task was successfully reassigned.", variant: "success") }
      end
    else
      Rails.logger.warn("[TaskAction] Task #{@task.id} could not be reassigned - #{@task.errors.full_messages.join(', ')}")
      respond_to do |format|
        format.html { redirect_to @task, alert: "Task could not be reassigned. #{@task.errors.full_messages.join(', ')}" }
        format.turbo_stream { render turbo_stream: task_turbo_streams(message: "Task could not be reassigned. #{@task.errors.full_messages.join(', ')}", variant: "danger") }
      end
    end
  end

  # GET /tasks/:id/download_results
  # Exports cracked hashes attributable to this task's attack as CSV.
  # Scoped to hashes cracked by this task's attack (hash_items.attack_id)
  # since per-task attribution is not tracked at the hash_item level.
  # Only available for completed or exhausted tasks.
  def download_results
    authorize! :download_results, @task

    unless @task.completed? || @task.exhausted?
      respond_to do |format|
        format.csv { redirect_to @task, alert: "Results can only be downloaded for completed or exhausted tasks." }
        format.html { redirect_to @task, alert: "Results can only be downloaded for completed or exhausted tasks." }
      end
      return
    end

    hash_items = HashItem.where(hash_list: @task.hash_list, attack: @task.attack, cracked: true)

    respond_to do |format|
      format.csv do
        send_data generate_csv(hash_items),
          filename: "task_#{@task.id}_results_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
          type: "text/csv"
      end
      format.html { redirect_to @task, alert: "CSV format required" }
    end
  end

  private

  # Generates CSV content from hash items.
  #
  # @param hash_items [ActiveRecord::Relation] Collection of HashItem records
  # @return [String] CSV formatted string with headers and data
  def generate_csv(hash_items)
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << ["Hash", "Plaintext", "Cracked At"]
      hash_items.find_each do |item|
        csv << [item.hash_value, item.plain_text, item.cracked_time&.iso8601]
      end
    end
  end

  # Builds an array of Turbo Stream actions for granular task UI updates.
  # Updates details card, actions buttons, error section, and appends a
  # toast notification so Turbo Stream users receive visual feedback
  # without a full page reload.
  def task_turbo_streams(message:, variant: "success")
    [
      turbo_stream.update("task-details-#{@task.id}", partial: "tasks/task", locals: { task: @task }),
      turbo_stream.replace("task-actions-#{@task.id}", partial: "tasks/task_actions", locals: { task: @task }),
      turbo_stream.replace("task-error-#{@task.id}", partial: "tasks/task_error", locals: { task: @task }),
      turbo_stream.append("toast_container", partial: "shared/toast", locals: { message: message, variant: variant })
    ]
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_task
    @task = Task.find(params[:id])
  end
end
