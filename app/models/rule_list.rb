# == Schema Information
#
# Table name: rule_lists
#
#  id                                           :bigint           not null, primary key
#  description(Description of the rule list)    :text
#  line_count(Number of lines in the rule list) :integer          default(0)
#  name(Name of the rule list)                  :string           not null, indexed
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
  validates_presence_of :name
  validates_uniqueness_of :name
end
