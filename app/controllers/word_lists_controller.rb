# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Controller for managing WordList resources.
#
# This controller handles CRUD operations for WordList objects. It ensures
# appropriate authentication and authorization checks are applied to all actions.
# The controller supports both HTML and JSON response formats for various actions.
#
# - Before Actions:
#   - `authenticate_user!`: Ensures the user is authenticated before accessing any actions.
#   - `load_and_authorize_resource`: Checks user permissions for accessing resources.
#   - `set_projects`: Loads accessible projects for `new`, `edit`, `create`, and `update` actions.
#
# Actions:
# - `index`: Lists all WordList objects.
# - `show`: Displays details of a single WordList object.
# - `new`: Renders a form for creating a new WordList object.
# - `edit`: Renders a form for editing an existing WordList object.
# - `create`: Creates a new WordList object. Assigns the current user as the creator,
#   ensures the user has read permissions for associated projects, and sets the `sensitive`
#   flag based on project associations. Responds with success or failure formats.
# - `update`: Updates an existing WordList object with permitted parameters. Responds
#   with success or failure formats.
# - `destroy`: Deletes an existing WordList object and redirects to the index page.
# Parameters:
# - `word_list_params`: Defines and permits trusted parameters for WordList objects.
#   Allowed parameters include:
#   - `name`: The name of the word list.
#   - `description`: A short description of the word list.
#   - `file`: The uploaded file associated with the word list.
#   - `line_count`: The count of lines in the word list.
#   - `sensitive`: A boolean indicating the sensitivity of the word list.
#   - `project_ids`: Array of associated project IDs.
# Protected Methods:
# - `word_list_params`: Handles strong parameter filtering for WordList attributes.
# Private Methods:
# - `set_projects`: Loads projects accessible to the current user based on their abilities.
# Note:
# - The controller uses the `Downloadable` module, which might provide additional functionality
#   for handling downloads (defined in a shared concern).
# - Actions are secured using CanCanCan's `load_and_authorize_resource` for fine-grained
#   access control.
class WordListsController < ApplicationController
  include Downloadable
  before_action :authenticate_user!
  load_and_authorize_resource
  before_action :set_projects, only: %i[new edit create update]

  # GET /word_lists or /word_lists.json
  def index; end

  # GET /word_lists/1 or /word_lists/1.json
  def show; end

  # GET /word_lists/new
  def new; end

  # GET /word_lists/1/edit
  def edit; end

  # POST /word_lists or /word_lists.json
  def create
    @word_list.assign_attributes(word_list_params)
    @word_list.creator = current_user

    return unless validate_project_authorization(@word_list.project_ids)

    @word_list.sensitive = @word_list.project_ids.any?

    respond_to do |format|
      if @word_list.save
        format.html { redirect_to word_list_url(@word_list), notice: "Word list was successfully created." }
        format.json { render :show, status: :created, location: @word_list }
      else
        Rails.logger.warn "WordList creation failed validation: #{@word_list.errors.full_messages.join(', ')}"
        Rails.logger.debug { "User: #{current_user.id}, Parameters: #{word_list_params.inspect}" }

        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @word_list.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /word_lists/1 or /word_lists/1.json
  def update
    new_project_ids = word_list_params[:project_ids]
    return unless validate_project_authorization(new_project_ids) if new_project_ids.present?

    respond_to do |format|
      if @word_list.update(word_list_params)
        @word_list.update(sensitive: @word_list.project_ids.any?)

        format.html { redirect_to word_list_url(@word_list), notice: "Word list was successfully updated." }
        format.json { render :show, status: :ok, location: @word_list }
      else
        Rails.logger.warn "WordList update failed validation: #{@word_list.errors.full_messages.join(', ')}"
        Rails.logger.debug { "User: #{current_user.id}, WordList ID: #{@word_list.id}" }

        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @word_list.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /word_lists/1 or /word_lists/1.json
  def destroy
    respond_to do |format|
      if @word_list.destroy
        format.html { redirect_to word_lists_url, notice: "Word list was successfully destroyed." }
        format.json { head :no_content }
      else
        Rails.logger.error "Failed to destroy WordList #{@word_list.id}: #{@word_list.errors.full_messages.join(', ')}"

        format.html do
          redirect_to word_lists_url,
                      alert: "Could not delete word list: #{@word_list.errors.full_messages.join(', ')}"
        end
        format.json do
          render json: {
            error: "Deletion failed",
            messages: @word_list.errors.full_messages
          }, status: :unprocessable_content
        end
      end
    end
  end

  protected

  # Only allow a list of trusted parameters through.
  def word_list_params
    params.expect(word_list: [:name, :description, :file, :line_count, :sensitive, project_ids: []])
  end

  private

  def set_projects
    @projects = Project.accessible_by(current_ability).chronological
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
    Rails.logger.error "WordList #{action_name} failed - invalid project_id: #{e.message}"
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
    Rails.logger.warn "WordList #{action_name} failed - unauthorized project access attempt"
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
