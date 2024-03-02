class AdminPolicy
  attr_reader :user

  # Initializes a new instance of the AdminPolicy class.
  #
  # @param user [User] the user object
  # @param _record [Object] the record object (not used in this method)
  def initialize(user, _record)
    @user = user
  end

  # Checks if the user has permission to access the index action.
  #
  # @return [Boolean] true if the user is not nil and is an admin, false otherwise.
  def index?
    user.nil? == false and user.admin?
  end
end
