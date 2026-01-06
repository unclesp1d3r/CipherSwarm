# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Controller responsible for managing MaskList resources.
# It provides actions to list, display, create, update, and delete mask lists.
#
# Filters and Callbacks:
# - `authenticate_user!`: Ensures that only authenticated users can access the actions.
# - `set_projects`: Sets accessible projects for specific actions.
# - `load_and_authorize_resource`: Enables loading and authorization of the MaskList resource.
#
# Accessible Routes:
# - GET /mask_lists: Lists all mask lists.
# - GET /mask_lists/:id: Displays a specific mask list.
# - GET /mask_lists/new: Displays a form for creating a new mask list.
# - GET /mask_lists/:id/edit: Displays a form for editing an existing mask list.
# - POST /mask_lists: Creates a new mask list.
# - PATCH/PUT /mask_lists/:id: Updates an existing mask list.
# - DELETE /mask_lists/:id: Deletes an existing mask list.
#
# The controller protects sensitive operations by authorizing relevant actions
# and managing associated project access.
class MaskListsController < ApplicationController
  include Downloadable
  before_action :authenticate_user!
  load_and_authorize_resource
  before_action :set_projects, only: %i[new edit create update]

  # GET /mask_lists or /mask_lists.json
  def index; end

  # GET /mask_lists/1 or /mask_lists/1.json
  def show; end

  # GET /mask_lists/new
  def new; end

  # GET /mask_lists/1/edit
  def edit; end

  # POST /mask_lists or /mask_lists.json
  def create
    @mask_list.assign_attributes(mask_list_params)
    @mask_list.creator = current_user

    return unless validate_project_authorization(@mask_list.project_ids)

    @mask_list.sensitive = @mask_list.project_ids.any?

    respond_to do |format|
      if @mask_list.save
        format.html { redirect_to mask_list_url(@mask_list), notice: "Mask list was successfully created." }
        format.json { render :show, status: :created, location: @mask_list }
      else
        Rails.logger.warn "MaskList creation failed validation: #{@mask_list.errors.full_messages.join(', ')}"
        Rails.logger.debug { "User: #{current_user.id}, Parameters: #{mask_list_params.inspect}" }

        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @mask_list.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /mask_lists/1 or /mask_lists/1.json
  def update
    new_project_ids = mask_list_params[:project_ids]
    return unless validate_project_authorization(new_project_ids) if new_project_ids.present?

    respond_to do |format|
      if @mask_list.update(mask_list_params)
        @mask_list.update(sensitive: @mask_list.project_ids.any?)

        format.html { redirect_to mask_list_url(@mask_list), notice: "Mask list was successfully updated." }
        format.json { render :show, status: :ok, location: @mask_list }
      else
        Rails.logger.warn "MaskList update failed validation: #{@mask_list.errors.full_messages.join(', ')}"
        Rails.logger.debug { "User: #{current_user.id}, MaskList ID: #{@mask_list.id}" }

        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @mask_list.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /mask_lists/1 or /mask_lists/1.json
  def destroy
    respond_to do |format|
      if @mask_list.destroy
        format.html { redirect_to mask_lists_url, notice: "Mask list was successfully destroyed." }
        format.json { head :no_content }
      else
        Rails.logger.error "Failed to destroy MaskList #{@mask_list.id}: #{@mask_list.errors.full_messages.join(', ')}"

        format.html do
          redirect_to mask_lists_url,
                      alert: "Could not delete mask list: #{@mask_list.errors.full_messages.join(', ')}"
        end
        format.json do
          render json: {
            error: "Deletion failed",
            messages: @mask_list.errors.full_messages
          }, status: :unprocessable_content
        end
      end
    end
  end

  protected

  # Only allow a list of trusted parameters through.
  def mask_list_params
    params.expect(mask_list: [:name, :description, :file, :sensitive, project_ids: []])
  end

  private

  def set_projects
    @projects = Project.accessible_by(current_ability)
  end

  # Validates that the current user has read access to all specified projects.
  # Handles RecordNotFound and AccessDenied exceptions with appropriate error responses.
  #
  # @param project_ids [Array<String, Integer>] Array of project IDs to validate
  # @return [Boolean] true if validation passes, false otherwise (renders error response)
  def validate_project_authorization(project_ids)
    return true if project_ids.blank?

    project_ids.compact_blank.each do |project_id|
      project = Project.find(project_id)
      authorize! :read, project
    end

    true
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "MaskList #{action_name} failed - invalid project_id: #{e.message}"
    Rails.logger.error "User: #{current_user.id}, IP: #{request.remote_ip}, Project IDs: #{project_ids.inspect}"

    respond_to do |format|
      format.html do
        flash.now[:error] = "One or more selected projects no longer exist. Please refresh the page and try again."
        render action_name == "create" ? :new : :edit, status: :unprocessable_content
      end
      format.json do
        render json: {
          error: "Invalid project selection",
          message: "One or more selected projects do not exist"
        }, status: :unprocessable_content
      end
    end

    false
  rescue CanCan::AccessDenied => e
    Rails.logger.warn "MaskList #{action_name} failed - unauthorized project access attempt"
    Rails.logger.warn "User: #{current_user.id}, IP: #{request.remote_ip}, Attempted project_ids: #{project_ids.inspect}"

    respond_to do |format|
      format.html do
        flash.now[:error] = "You don't have permission to associate this resource with one or more selected projects."
        render action_name == "create" ? :new : :edit, status: :forbidden
      end
      format.json do
        render json: {
          error: "Forbidden",
          message: "You don't have permission to access one or more selected projects"
        }, status: :forbidden
      end
    end

    false
  end
end
