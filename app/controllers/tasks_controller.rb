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
# - `before_action :set_task` loads the task for the show action.
class TasksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_task

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
