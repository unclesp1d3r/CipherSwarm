class ProjectPolicy < ApplicationPolicy
  attr_reader :user, :project

  # Initializes a new instance of the ProjectPolicy class.
  #
  # @param user [User] the user object
  # @param project [Project] the project object
  def initialize(user, project)
    @user = user
    @project = project
  end

  # Determines whether the current user is allowed to view the project index.
  #
  # @return [Boolean] true if the user is allowed to view the project index, false otherwise.
  def index?
    @project.users.in?(@user) or user.admin?
  end

  # Determines whether the project can be viewed by a user.
  #
  # @return [Boolean] true if the user is the owner of the project or an admin, false otherwise.
  def show?
    @project.users.in?(@user) or user.admin?
  end

  # Determines whether the current user is allowed to update the project.
  #
  # @return [Boolean] true if the user is allowed to update the project, false otherwise.
  def update?
    @project.users.in?(@user) or user.admin?
  end

  # Determines whether the current user has permission to destroy a project.
  #
  # @return [Boolean] true if the user has permission, false otherwise.
  def destroy?
    @project.users.in?(@user) or user.admin?
  end
end
