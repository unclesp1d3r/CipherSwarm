# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

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
FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.email }
    password { "password" }
    password_confirmation { "password" }

    factory :admin do
      after(:create) { |user| user.add_role(:admin) }
    end
  end
end
