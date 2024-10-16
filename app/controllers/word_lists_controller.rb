# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

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
    @word_list = WordList.new(word_list_params)
    @word_list.creator = current_user
    @word_list.project_ids.each { |project_id| authorize! :read, Project.find(project_id) }
    @word_list.sensitive = @word_list.project_ids.any?

    respond_to do |format|
      if @word_list.save
        format.html { redirect_to word_list_url(@word_list), notice: "Word list was successfully created." }
        format.json { render :show, status: :created, location: @word_list }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @word_list.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /word_lists/1 or /word_lists/1.json
  def update
    respond_to do |format|
      if @word_list.update(word_list_params)
        format.html { redirect_to word_list_url(@word_list), notice: "Word list was successfully updated." }
        format.json { render :show, status: :ok, location: @word_list }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @word_list.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /word_lists/1 or /word_lists/1.json
  def destroy
    @word_list.destroy!

    respond_to do |format|
      format.html { redirect_to word_lists_url, notice: "Word list was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  protected

  # Only allow a list of trusted parameters through.
  def word_list_params
    params.require(:word_list).permit(:name, :description, :file, :line_count, :sensitive, project_ids: [])
  end

  private

  def set_projects
    @projects = Project.accessible_by(current_ability)
  end
end
