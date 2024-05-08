# frozen_string_literal: true

# Module for adding controller macros to RSpec tests.
module ControllerMacros
  def login_user
    before do
      @request.env["devise.mapping"] = Devise.mappings[:user]
      user = FactoryBot.create(:user)
      sign_in user
    end
  end
end
