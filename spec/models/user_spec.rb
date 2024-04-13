# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                                                :bigint           not null, primary key
#  current_sign_in_at                                :datetime
#  current_sign_in_ip                                :string
#  email                                             :string(50)       default(""), not null, indexed
#  encrypted_password                                :string           default(""), not null
#  failed_attempts                                   :integer          default(0), not null
#  last_sign_in_at                                   :datetime
#  last_sign_in_ip                                   :string
#  locked_at                                         :datetime
#  name(Unique username. Used for login.)            :string           not null, indexed
#  remember_created_at                               :datetime
#  reset_password_sent_at                            :datetime
#  reset_password_token                              :string           indexed
#  role(The role of the user, either basic or admin) :integer          default("basic")
#  sign_in_count                                     :integer          default(0), not null
#  unlock_token                                      :string           indexed
#  created_at                                        :datetime         not null
#  updated_at                                        :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_name                  (name) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#
require "rails_helper"

RSpec.describe User do
  describe "validations" do
    subject { create(:user) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_confirmation_of(:password) }
    it { is_expected.to normalize(:email).from("TEST@test.com ").to("test@test.com") }
  end

  describe "associations" do
    it { is_expected.to have_many(:agents) }
    it { is_expected.to have_many(:project_user).dependent(:destroy) }
    it { is_expected.to have_many(:projects).through(:project_user) }
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:role).with_values(basic: 0, admin: 1) }
  end
end
