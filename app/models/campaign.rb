# frozen_string_literal: true

# == Schema Information
#
# Table name: campaigns
#
#  id            :bigint           not null, primary key
#  attacks_count :integer          default(0), not null
#  description   :text
#  name          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  hash_list_id  :bigint           not null, indexed
#  project_id    :bigint           indexed
#
# Indexes
#
#  index_campaigns_on_hash_list_id  (hash_list_id)
#  index_campaigns_on_project_id    (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (hash_list_id => hash_lists.id)
#  fk_rails_...  (project_id => projects.id)
#
class Campaign < ApplicationRecord
  audited unless Rails.env.test?
  belongs_to :hash_list
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
end
