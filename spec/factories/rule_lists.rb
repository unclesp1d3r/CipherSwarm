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
FactoryBot.define do
  factory :rule_list do
    name { Faker::Lorem.word }
    sensitive { false }
    description { Faker::Lorem.paragraph }
    projects { [ create(:project) ] }

    after(:build) do |rule_list|
      rule_list.file.attach(
        io: Rails.root.join("spec/fixtures/rule_lists/dive.rule").open,
        filename: "dive.rule", content_type: "text/plain")
    end
  end
end
