# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Controller for managing Projects. This class provides actions for handling
# CRUD operations for Project resources. It ensures authorization and user
# authentication for access control.
#
# Filters:
# - `before_action :authenticate_user!`: Ensures only authenticated users can access the actions.
# - `load_and_authorize_resource`: Integrates with CanCanCan for authorization.
#
# Actions:
#
# - `show`: Renders the details of a specific project.
# - `new`: Initializes a new Project instance for creation.
# - `edit`: Fetches an existing project to prepare for editing.
# - `create`: Handles the creation of a new project. Validates input parameters
#   and responds accordingly with success or failure formats (HTML/JSON).
# - `update`: Updates an existing project. Executes validations and handles
#   success or failure responses in multiple formats (HTML/JSON).
# - `destroy`: Deletes a project from the database. Responds with appropriate
#   status after deletion.
#
# Private Methods:
#
# - `project_params`: Strong parameters configuration. Ensures only permitted
#   attributes (`:name`, `:description`, `user_ids`) are accepted.
# - `set_project`: Fetches a specific project by its ID. Used internally by
#   callbacks or actions requiring a loaded project instance.
class ProjectsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource
  # GET /projects/1 or /projects/1.json
  def show; end

  # GET /projects/new
  def new; end

  # GET /projects/1/edit
  def edit; end

  # POST /projects or /projects.json
  def create
    @project = Project.new(project_params)

    respond_to do |format|
      if @project.save
        format.html { redirect_to project_url(@project), notice: "Project was successfully created." }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @project.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /projects/1 or /projects/1.json
  def update
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to project_url(@project), notice: "Project was successfully updated." }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @project.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /projects/1 or /projects/1.json
  def destroy
    @project.destroy!

    respond_to do |format|
      format.html { redirect_to admin_index_url, notice: "Project was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Only allow a list of trusted parameters through.
  def project_params
    params.require(:project).permit(:name, :description, user_ids: [])
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_project
    @project = Project.find(params[:id])
  end
end
