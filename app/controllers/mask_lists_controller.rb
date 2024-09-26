# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class MaskListsController < ApplicationController
  include Downloadable
  before_action :authenticate_user!
  before_action :set_projects, only: %i[new edit create update]
  load_and_authorize_resource

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
    @mask_list = MaskList.new(mask_list_params)
    @mask_list.creator = current_user
    @mask_list.project_ids.each { |project_id| authorize! :read, Project.find(project_id) }
    @mask_list.sensitive = @mask_list.project_ids.any?

    respond_to do |format|
      if @mask_list.save
        format.html { redirect_to mask_list_url(@mask_list), notice: "Mask list was successfully created." }
        format.json { render :show, status: :created, location: @mask_list }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @mask_list.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /mask_lists/1 or /mask_lists/1.json
  def update
    respond_to do |format|
      if @mask_list.update(mask_list_params)
        format.html { redirect_to mask_list_url(@mask_list), notice: "Mask list was successfully updated." }
        format.json { render :show, status: :ok, location: @mask_list }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @mask_list.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /mask_lists/1 or /mask_lists/1.json
  def destroy
    @mask_list.destroy!

    respond_to do |format|
      format.html { redirect_to mask_lists_url, notice: "Mask list was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  protected

  # Only allow a list of trusted parameters through.
  def mask_list_params
    params.require(:mask_list).permit(:name, :description, :file, :sensitive, project_ids: [])
  end

  def set_projects
    @projects = Project.accessible_by(current_ability)
  end
end
