class AdminPolicy
  attr_reader :user

  def initialize(user, _record)
    @user = user
  end

  def index?
    user.nil? == false and user.admin?
  end
end
