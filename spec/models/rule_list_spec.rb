# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

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
require "rails_helper"

RSpec.describe RuleList do
  subject { create(:rule_list) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_numericality_of(:line_count).only_integer.is_greater_than_or_equal_to(0).allow_nil }
  end

  describe "associations" do
    it { is_expected.to have_and_belong_to_many(:projects) }
  end

  describe "file attachment" do
    it { is_expected.to have_one_attached(:file) }
  end

  describe "scopes" do
    describe ".sensitive" do
      it "returns only sensitive rule lists" do
        sensitive_rule_list = create(:rule_list, sensitive: true, name: "sensitive")
        create(:rule_list, sensitive: false, name: "not_sensitive")

        expect(described_class.sensitive).to eq([sensitive_rule_list])
      end
    end
  end
end
