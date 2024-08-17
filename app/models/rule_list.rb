# frozen_string_literal: true

# == Schema Information
#
# Table name: rule_lists
#
#  id                                           :bigint           not null, primary key
#  description(Description of the rule list)    :text
#  line_count(Number of lines in the rule list) :bigint           default(0)
#  name(Name of the rule list)                  :string           not null, indexed
#  processed                                    :boolean          default(FALSE), not null
#  sensitive(Sensitive rule list)               :boolean          default(FALSE), not null
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#
# Indexes
#
#  index_rule_lists_on_name  (name) UNIQUE
#
class RuleList < ApplicationRecord
  include AttackResource
end
