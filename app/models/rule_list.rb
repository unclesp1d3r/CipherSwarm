# == Schema Information
#
# Table name: rule_lists
#
#  id                                           :bigint           not null, primary key
#  description(Description of the rule list)    :text
#  line_count(Number of lines in the rule list) :integer          default(0)
#  name(Name of the rule list)                  :string           not null, indexed
#  processed                                    :boolean          default(FALSE)
#  sensitive(Sensitive rule list)               :boolean          default(FALSE)
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#
# Indexes
#
#  index_rule_lists_on_name  (name) UNIQUE
#
class RuleList < ApplicationRecord
  has_one_attached :file
  has_and_belongs_to_many :projects
  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }
  validates :file, attached: true, content_type: %i[text/plain]
  validates :line_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  has_and_belongs_to_many :attacks, foreign_key: :rule_list_id, join_table: :operations_rule_lists

  scope :sensitive, -> { where(sensitive: true) }

  after_save :update_line_count, if: :file_attached?
  broadcasts_refreshes

  private

  def file_attached?
    file.attached?
  end

  def update_line_count
    if Rails.env.test?
      CountFileLinesJob.perform_now(id, "RuleList")
      return
    end
    CountFileLinesJob.perform_later(id, "RuleList")
  end
end
