# frozen_string_literal: true

#
# The Campaign model represents a campaign in the CipherSwarm application.
# A campaign is associated with a hash list and a project, and it can have many attacks and tasks.
#
# Associations:
# - belongs_to :hash_list, touch: true
# - has_many :attacks, dependent: :destroy
# - belongs_to :project, touch: true
# - has_many :tasks, through: :attacks, dependent: :destroy
#
# Validations:
# - validates :name, presence: true
# - validates_associated :hash_list
# - validates_associated :project
#
# Scopes:
# - default_scope { order(:created_at) }
# - scope :completed, -> { joins(:attacks).where(attacks: { state: :completed }) }
# - scope :in_projects, ->(ids) { where(project_id: ids) }
#
# Delegations:
# - delegate :uncracked_count, to: :hash_list
# - delegate :cracked_count, to: :hash_list
# - delegate :hash_item_count, to: :hash_list
#
# Methods:
# - completed?: Checks if the campaign is completed.
# - pause: Pauses all associated attacks for the campaign.
# - paused?: Checks if the campaign is paused.
# - resume: Resumes all attacks associated with the campaign.
# == Schema Information
#
# Table name: campaigns
#
#  id            :bigint           not null, primary key
#  attacks_count :integer          default(0), not null
#  deleted_at    :datetime         indexed
#  description   :text
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  hash_list_id  :bigint           not null, indexed
#  project_id    :bigint           not null, indexed
#
# Indexes
#
#  index_campaigns_on_deleted_at    (deleted_at)
#  index_campaigns_on_hash_list_id  (hash_list_id)
#  index_campaigns_on_project_id    (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (hash_list_id => hash_lists.id) ON DELETE => cascade
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#
class Campaign < ApplicationRecord
  acts_as_paranoid
  belongs_to :hash_list, touch: true
  has_many :attacks, dependent: :destroy
  belongs_to :project, touch: true
  has_many :tasks, through: :attacks, dependent: :destroy

  validates :name, presence: true
  validates_associated :hash_list
  validates_associated :project

  default_scope { order(:created_at) }
  scope :completed, -> { joins(:attacks).where(attacks: { state: :completed }) }
  scope :in_projects, ->(ids) { where(project_id: ids) }

  broadcasts_refreshes unless Rails.env.test?

  delegate :uncracked_count, to: :hash_list
  delegate :cracked_count, to: :hash_list
  delegate :hash_item_count, to: :hash_list

  # Checks if the campaign is completed.
  #
  # A campaign is considered completed if all the hash items in the hash list have been cracked
  # or all the attacks associated with the campaign are in the completed state.
  #
  # @return [Boolean] true if the campaign is completed, false otherwise.
  def completed?
    hash_list.uncracked_items.empty? || attacks.where.not(state: :completed).empty?
  end

  # Pauses all associated attacks for the campaign.
  # Iterates through each attack associated with the campaign and calls the `pause` method on it.
  def pause
    attacks.find_each(&:pause)
  end

  # Checks if the campaign is paused.
  #
  # A campaign is considered paused if there are no attacks in states other than
  # paused, completed, or running, and there is at least one attack in the paused state.
  #
  # @return [Boolean] true if the campaign is paused, false otherwise.
  def paused?
    !attacks.without_states(%i[paused completed running]).any? && attacks.with_state(:paused).any?
  end

  # Resumes all attacks associated with the campaign.
  # Iterates through each attack and calls the `resume` method on it.
  def resume
    attacks.find_each(&:resume)
  end
end
