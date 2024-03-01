# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  locked_at              :datetime
#  name                   :string           not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :integer
#  sign_in_count          :integer          default(0), not null
#  unlock_token           :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_name                  (name) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#
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
