# == Schema Information
#
# Table name: word_lists
#
#  id                                                 :bigint           not null, primary key
#  description(Description of the word list)          :text
#  line_count(Number of lines in the word list)       :integer
#  name(Name of the word list)                        :string           indexed
#  processed                                          :boolean          default(FALSE), indexed
#  sensitive(Is the word list sensitive?)             :boolean
#  created_at                                         :datetime         not null
#  updated_at                                         :datetime         not null
#  project_id(Project to which the word list belongs) :bigint           not null, indexed
#
# Indexes
#
#  index_word_lists_on_name        (name) UNIQUE
#  index_word_lists_on_processed   (processed)
#  index_word_lists_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
FactoryBot.define do
  factory :word_list do
    name { "MyString" }
    description { "MyText" }
    file { nil }
    line_count { 1 }
    sensitive { false }
  end
end
