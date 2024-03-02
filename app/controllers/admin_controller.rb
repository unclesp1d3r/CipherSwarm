class AdminController < ApplicationController
  def index
    authorize :admin, :index?
    @users = User.all.includes(:projects)
    @projects = Project.all.includes(:users)
  end

  def unlock_user
    user = User.find(params[:id])
    user.unlock_access!
    redirect_to admin_index_path
  end

  def lock_user
    user = User.find(params[:id])
    user.lock_access!
    redirect_to admin_index_path
  end
end
