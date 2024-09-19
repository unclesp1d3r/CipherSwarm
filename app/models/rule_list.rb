# frozen_string_literal: true

# The RuleList class represents a list of hashcat rules within the CipherSwarm application.
# It includes the AttackResource module, which provides additional functionality
# related to attack resources.
#
# @see AttackResource
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
#  creator_id(The user who created this list)   :bigint           indexed
#
# Indexes
#
#  index_rule_lists_on_creator_id  (creator_id)
#  index_rule_lists_on_name        (name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#
class RuleList < ApplicationRecord
  include AttackResource
end
