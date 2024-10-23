# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AttackResourceController < ApplicationController
  before_action :authenticate_user!
  before_action :set_projects, only: %i[new edit create update]
  load_and_authorize_resource

  def index
    @resources = resource_class.accessible_by(current_ability)
    render json: @resources
  end

  def show
    render json: @resource
  end

  def create
    @resource = resource_class.new(resource_params)
    @resource.creator = current_user
    if @resource.save
      render json: @resource, status: :created
    else
      render json: @resource.errors, status: :unprocessable_entity
    end
  end

  def update
    if @resource.update(resource_params)
      render json: @resource
    else
      render json: @resource.errors, status: :unprocessable_entity
    end
  end

  def destroy
    @resource.destroy
    head :no_content
  end

  private

  def set_projects
    @projects = Project.accessible_by(current_ability)
  end

  def resource_class
    controller_name.classify.constantize
  end

  def resource_params
    params.require(controller_name.singularize.to_sym).permit(:name, :description, :file, :sensitive, project_ids: [])
  end
end
