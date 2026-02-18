# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The RuleListsController handles CRUD actions for RuleList resources.
#
# This controller ensures that users can create, view, edit, and delete
# rule lists while adhering to authentication and authorization checks.
# Additionally, it supports JSON responses for API compatibility and handles
# file-based operations.
class RuleListsController < ApplicationController
  include Downloadable
  before_action :authenticate_user!
  load_and_authorize_resource
  before_action :set_projects, only: %i[new edit create update]

  # GET /rule_lists or /rule_lists.json
  def index; end

  # GET /rule_lists/1 or /rule_lists/1.json
  def show; end

  # GET /rule_lists/new
  def new; end

  # GET /rule_lists/1/edit
  def edit; end

  # POST /rule_lists or /rule_lists.json
  def create
    @rule_list.assign_attributes(rule_list_params)
    @rule_list.creator = current_user

    return unless validate_project_authorization(@rule_list.project_ids)

    @rule_list.sensitive = @rule_list.project_ids.any?

    respond_to do |format|
      if @rule_list.save
        format.html { redirect_to rule_list_url(@rule_list), notice: "Rule list was successfully created." }
        format.json { render :show, status: :created, location: @rule_list }
      else
        Rails.logger.warn "RuleList creation failed validation: #{@rule_list.errors.full_messages.join(', ')}"
        Rails.logger.debug { "User: #{current_user.id}, Parameters: #{rule_list_params.inspect}" }

        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @rule_list.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /rule_lists/1 or /rule_lists/1.json
  def update
    new_project_ids = rule_list_params[:project_ids]
    return unless validate_project_authorization(new_project_ids) if new_project_ids.present?

    respond_to do |format|
      if @rule_list.update(rule_list_params)
        @rule_list.update(sensitive: @rule_list.project_ids.any?)

        format.html { redirect_to rule_list_url(@rule_list), notice: "Rule list was successfully updated." }
        format.json { render :show, status: :ok, location: @rule_list }
      else
        Rails.logger.warn "RuleList update failed validation: #{@rule_list.errors.full_messages.join(', ')}"
        Rails.logger.debug { "User: #{current_user.id}, RuleList ID: #{@rule_list.id}" }

        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @rule_list.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /rule_lists/1 or /rule_lists/1.json
  def destroy
    respond_to do |format|
      if @rule_list.destroy
        format.html { redirect_to rule_lists_url, notice: "Rule list was successfully destroyed." }
        format.json { head :no_content }
      else
        Rails.logger.error "Failed to destroy RuleList #{@rule_list.id}: #{@rule_list.errors.full_messages.join(', ')}"

        format.html do
          redirect_to rule_lists_url,
                      alert: "Could not delete rule list: #{@rule_list.errors.full_messages.join(', ')}"
        end
        format.json do
          render json: {
            error: "Deletion failed",
            messages: @rule_list.errors.full_messages
          }, status: :unprocessable_content
        end
      end
    end
  end

  protected

  # Only allow a list of trusted parameters through.
  def rule_list_params
    params.expect(rule_list: [:name, :description, :file, :line_count, :sensitive, project_ids: []])
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
    Rails.logger.error "RuleList #{action_name} failed - invalid project_id: #{e.message}"
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
    Rails.logger.warn "RuleList #{action_name} failed - unauthorized project access attempt"
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
