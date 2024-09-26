# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The User model represents a user in the CipherSwarm application.
# It includes various modules and validations to handle authentication,
# role management, and associations with other models.
#
# Attributes:
#   - name: The name of the user.
#   - email: The email address of the user.
#
# Validations:
#   - Validates presence and uniqueness (case insensitive) of name and email.
#   - Validates length of name and email to be a maximum of 50 characters.
#
# Associations:
#   - has_many :project_users, dependent: :destroy
#   - has_many :projects, through: :project_users
#   - has_many :agents, dependent: :restrict_with_error
#
# Callbacks:
#   - after_create :assign_default_role
#
# Scopes:
#   - default_scope { order(:created_at) }
#
# Normalizations:
#   - Normalizes email and name by stripping whitespace and converting to lowercase.
#
# Methods:
#   - admin?: Checks if the user has an admin role.
#   - all_project_ids: Returns the project IDs associated with the user.
#
# Auditing:
#   - Audits changes to the user model, except for certain attributes, unless in test environment.
#
# Broadcasting:
#   - Broadcasts refreshes unless in test environment.
#
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
#  role(The role of the user, either basic or admin) :integer          default(0)
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
class User < ApplicationRecord
  rolify
  unless Rails.env.test?
    audited except: %i[current_sign_in_at current_sign_in_ip last_sign_in_at
      last_sign_in_ip sign_in_count]
  end
  # Include default devise modules. Others available are:
  # :registerable, :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :lockable, :trackable,
         :recoverable, :rememberable, :validatable, :registerable
  validates :name, :email, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 50 }
  has_many :project_users, dependent: :destroy
  has_many :projects, through: :project_users
  has_many :agents, dependent: :restrict_with_error # Prevents deletion of agents if they are associated with a user.
  has_many :mask_lists, foreign_key: :creator_id, dependent: :restrict_with_error, inverse_of: :creator
  has_many :word_lists, foreign_key: :creator_id, dependent: :restrict_with_error, inverse_of: :creator
  has_many :rule_lists, foreign_key: :creator_id, dependent: :restrict_with_error, inverse_of: :creator

  after_create :assign_default_role

  default_scope { order(:created_at) }

  normalizes :email, with: ->(value) { value.strip.downcase }
  normalizes :name, with: ->(value) { value.strip.downcase }

  broadcasts_refreshes unless Rails.env.test?

  kredis_boolean :hide_completed_activities, default: false

  # Checks if the user has an admin role.
  # @return [Boolean] True if the user has an admin role, false otherwise.
  def admin?
    has_role?(:admin)
  end

  # Returns the project IDs associated with the user.
  # @return [Array<Integer>] The project IDs associated with the user.
  def all_project_ids
    Rails.cache.fetch("#{cache_key_with_version}/all_project_ids", expires_in: 1.hour) do
      projects.pluck(:id)
    end
  end

  def hide_completed_activities?
    !!self.hide_completed_activities.value
  end

  def toggle_hide_completed_activities
    self.hide_completed_activities.value = !self.hide_completed_activities.value
  end

  private

  # Assigns the default role of :basic to the user if the user does not have any roles.
  #
  # @return [void]
  def assign_default_role
    self.add_role(:basic) if self.roles.blank?
  end
end
