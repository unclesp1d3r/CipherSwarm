# == Schema Information
#
# Table name: campaigns
#
#  id           :bigint           not null, primary key
#  name         :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  hash_list_id :bigint           not null, indexed
#  project_id   :bigint           indexed
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
  audited
  belongs_to :hash_list
  has_many :attacks
  belongs_to :project, touch: true

  validates :name, presence: true
  validates :hash_list, presence: true
  validates :project, presence: true

  scope :completed, -> { joins(:attacks).where(attacks: { status: :completed }) }
  scope :in_projects, ->(ids) { where("project_id IN (?)", ids) }

  def completed?
    if hash_list.uncracked_items.empty?
      return true
    end

    attacks.where.not(status: :completed).empty?
  end
end