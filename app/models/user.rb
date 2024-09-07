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

  after_create :assign_default_role

  default_scope { order(:created_at) }

  normalizes :email, with: ->(value) { value.strip.downcase }
  normalizes :name, with: ->(value) { value.strip.downcase }

  broadcasts_refreshes unless Rails.env.test?

  # Checks if the user has an admin role.
  # @return [Boolean] True if the user has an admin role, false otherwise.
  def admin?
    has_role?(:admin)
  end

  # Returns the project IDs associated with the user.
  # @return [Array<Integer>] The project IDs associated with the user.
  def all_project_ids
    projects.pluck(:id)
  end

  private

  def assign_default_role
    self.add_role(:basic) if self.roles.blank?
  end
end
