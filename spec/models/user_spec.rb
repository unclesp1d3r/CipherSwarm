require 'rails_helper'

RSpec.describe User, type: :model do
  it "is not valid without a name" do
    user = User.new(name: nil)
    expect(user).to_not be_valid
  end
  it "is not valid without an email" do
    user = User.new(email: nil)
    expect(user).to_not be_valid
  end
  it "is valid with a name, email, and password" do
    user = User.new(name: "Test", email: "test@test.com")
    user.password = "password"
    user.password_confirmation = "password"

    expect(user).to be_valid
  end
  it "is has a role of user by default" do
    user = User.new(name: "Test", email: "test@test.com")
    user.password = "password"
    user.password_confirmation = "password"
    user.save!
    expect(user.role).to eq("basic")
  end
end
