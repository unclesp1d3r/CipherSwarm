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
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@task, partial: "tasks/task", locals: { task: @task }) }
      end
    else
      Rails.logger.warn("[TaskAction] Task #{@task.id} could not be cancelled - current state: #{@task.state}")
      respond_to do |format|
        format.html { redirect_to @task, alert: "Task could not be cancelled. Only pending or running tasks can be cancelled." }
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@task, partial: "tasks/task", locals: { task: @task }) }
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
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@task, partial: "tasks/task", locals: { task: @task }) }
      end
    else
      Rails.logger.warn("[TaskAction] Task #{@task.id} could not be retried - current state: #{@task.state}")
      respond_to do |format|
        format.html { redirect_to @task, alert: "Task could not be retried. Only failed tasks can be retried." }
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@task, partial: "tasks/task", locals: { task: @task }) }
      end
    end
  end

  # GET /tasks/1 or /tasks/1.json
  def show
    authorize! :read, @task
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_task
    @task = Task.find(params[:id])
  end
end
