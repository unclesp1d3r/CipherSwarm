class ProjectPolicy < ApplicationPolicy
  attr_reader :user, :project

  def initialize(user, project)
    @user = user
    @project = project
  end

  def index?
    # Only allow the owner of the project to view it
    @project.users.in?(@user) or user.admin?
  end

  def show?
    # Only allow the owner of the project to view it
    @project.users.in?(@user) or user.admin?
  end

  def update?
    # Only allow the owner of the project to update it
    @project.users.in?(@user) or user.admin?
  end

  def destroy?
    # Only allow the owner of the project to destroy it
    @project.users.in?(@user) or user.admin?
  end
end
