# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The User class represents a user in the system. It includes authentication,
# validation, role management, auditing (when not in test environment),
# associations, and additional behavior through Devise and other modules.
#
# Modules used:
# - rolify: Handles role-based functionality.
# - audited: Tracks changes to the model's attributes, excluding certain fields
#   like login tracking fields (e.g., current_sign_in_at, sign_in_count).
# - devise: Manages user authentication and related functionality.
#
# Callbacks:
# - After creating a user, assigns a default role of :basic if no roles are associated.
#
# Validations:
# - Validates presence, uniqueness (case-insensitive), and length of name and email fields.
#
# Relationships:
# - Has many project_users, projects (through project_users), agents, mask_lists,
#   word_lists, and rule_lists. Deletion is restricted for associated agents, mask_lists,
#   word_lists, and rule_lists.
#
# Scopes:
# - Sorted by creation date by default.
#
# Attribute Normalization:
# - Normalizes the name and email fields by stripping whitespace and converting
#   to lowercase.
#
# Broadcasts:
# - Sends refresh messages after create, update, and destroy operations unless
#   in a test environment.
#
# Kredis:
# - kredis_boolean attribute `hide_completed_activities` with a default value of false.
#
# Instance Methods:
# - admin?: Checks whether the user has an admin role.
# - all_project_ids: Returns the IDs of projects associated with the user, cached
#   for better performance.
# - hide_completed_activities?: Returns the boolean value of hide_completed_activities.
# - toggle_hide_completed_activities: Toggles the value of hide_completed_activities.
#
# Private Methods:
# - assign_default_role: Assigns the :basic role to the user if no other roles are present.
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
