# frozen_string_literal: true

class ProjectsController < ApplicationController
  before_action :set_project, only: %i[ show edit update destroy ]

  # GET /projects/1 or /projects/1.json
  def show
    authorize! :read, @project
  end

  # GET /projects/new
  def new
    authorize! :create, Project
    @project = Project.new
  end

  # GET /projects/1/edit
  def edit
    authorize! :edit, @project
  end

  # POST /projects or /projects.json
  def create
    @project = Project.new(project_params)
    authorize! :create, @project

    respond_to do |format|
      if @project.save
        format.html { redirect_to project_url(@project), notice: "Project was successfully created." }
        format.json { render :show, status: :created, location: @project }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1 or /projects/1.json
  def update
    authorize! :update, @project
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to project_url(@project), notice: "Project was successfully updated." }
        format.json { render :show, status: :ok, location: @project }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1 or /projects/1.json
  def destroy
    authorize! :destroy, @project
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
