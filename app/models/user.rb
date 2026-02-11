# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Represents a user in the system with authentication, role management, and project associations.
#
# @modules
# - rolify: role management
# - audited: tracks changes (except login fields)
# - devise: authentication
#
# @relationships
# - has_many :project_users, :projects (through project_users)
# - has_many :agents (restrict_with_error)
# - has_many :mask_lists, :word_lists, :rule_lists (as creator, restrict_with_error)
#
# @validations
# - name, email: present, unique (case insensitive), max 50 chars
#
# @callbacks
# - after_create: assigns default :basic role if no roles present
#
# @normalizations
# - name, email: stripped and downcased
#
# == Schema Information
#
# Table name: users
#
#  id                                                :bigint           not null, primary key
#  auth_migrated                                     :boolean          default(FALSE), not null, indexed
#  current_sign_in_at                                :datetime
#  current_sign_in_ip                                :string
#  email                                             :string(50)       default(""), not null, uniquely indexed
#  encrypted_password                                :string           default(""), not null
#  failed_attempts                                   :integer          default(0), not null
#  last_sign_in_at                                   :datetime
#  last_sign_in_ip                                   :string
#  locked_at                                         :datetime
#  name(Unique username. Used for login.)            :string           not null, uniquely indexed
#  password_digest                                   :string
#  remember_created_at                               :datetime
#  reset_password_sent_at                            :datetime
#  reset_password_token                              :string           uniquely indexed
#  role(The role of the user, either basic or admin) :integer          default(0)
#  sign_in_count                                     :integer          default(0), not null
#  unlock_token                                      :string           uniquely indexed
#  created_at                                        :datetime         not null
#  updated_at                                        :datetime         not null
#
# Indexes
#
#  index_users_on_auth_migrated         (auth_migrated)
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
  has_many :campaigns, foreign_key: :creator_id, dependent: :restrict_with_error, inverse_of: :creator
  has_many :hash_lists, foreign_key: :creator_id, dependent: :restrict_with_error, inverse_of: :creator
  has_many :attacks, foreign_key: :creator_id, dependent: :restrict_with_error, inverse_of: :creator

  after_create :assign_default_role

  self.implicit_order_column = :created_at

  normalizes :email, with: ->(value) { value.strip.downcase }
  normalizes :name, with: ->(value) { value.strip.downcase }

  include SafeBroadcasting

  broadcasts_refreshes

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
    hide_completed_activities
  end

  def toggle_hide_completed_activities
    update!(hide_completed_activities: !hide_completed_activities)
  end

  private

  # Assigns the default role of :basic to the user if the user does not have any roles.
  #
  # @return [void]
  def assign_default_role
    self.add_role(:basic) if self.roles.blank?
  end
end
