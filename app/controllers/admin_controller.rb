class AdminController < ApplicationController
  # Retrieves all users and projects and renders the index view.
  #
  # This method is responsible for authorizing the user to manage all resources,
  # retrieving all users and projects from the database, and then rendering the
  # index view with the retrieved data.
  def index
    authorize! :manage, :all
    @users = User.all.includes(:projects)
    @projects = Project.all.includes(:users)
  end

  # Unlocks a user's access.
  #
  # This method is responsible for unlocking a user's access by calling the `unlock_access!` method on the user object.
  # It requires the user to have the necessary authorization to manage all resources.
  #
  # Params:
  # - params[:id] (Integer) - The ID of the user to unlock.
  #
  # Returns:
  # - None
  #
  # Example usage:
  #   unlock_user
  #
  def unlock_user
    authorize! :manage, :all
    user = User.find(params[:id])
    user.unlock_access!
    redirect_to admin_index_path
  end

  # Locks the access for a user.
  #
  # This method is used to lock the access for a specific user. It requires the user to have the ability to manage all resources.
  #
  # Params:
  # - params[:id] (Integer): The ID of the user to lock.
  #
  # Returns:
  # - None
  #
  # Example:
  #   lock_user
  #
  def lock_user
    authorize! :manage, :all
    user = User.find(params[:id])
    user.lock_access!
    redirect_to admin_index_path
  end
end
