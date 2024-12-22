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

  def create
    @rule_list = RuleList.new(rule_list_params)
    @rule_list.creator = current_user
    @rule_list.project_ids.each { |project_id| authorize! :read, Project.find(project_id) }
    @rule_list.sensitive = @rule_list.project_ids.any?

    respond_to do |format|
      if @rule_list.save
        format.html { redirect_to rule_list_url(@rule_list), notice: "Rule list was successfully created." }
        format.json { render :show, status: :created, location: @rule_list }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @rule_list.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /rule_lists/1 or /rule_lists/1.json
  def update
    respond_to do |format|
      if @rule_list.update(rule_list_params)
        format.html { redirect_to rule_list_url(@rule_list), notice: "Rule list was successfully updated." }
        format.json { render :show, status: :ok, location: @rule_list }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @rule_list.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /rule_lists/1 or /rule_lists/1.json
  def destroy
    @rule_list.destroy!

    respond_to do |format|
      format.html { redirect_to rule_lists_url, notice: "Rule list was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  protected

  # Only allow a list of trusted parameters through.
  def rule_list_params
    params.require(:rule_list).permit(:name, :description, :file, :line_count, :sensitive, project_ids: [])
  end

  private

  def set_projects
    @projects = Project.accessible_by(current_ability)
  end
end
