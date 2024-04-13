# frozen_string_literal: true

# == Schema Information
#
# Table name: word_lists
#
#  id                                           :bigint           not null, primary key
#  description(Description of the word list)    :text
#  line_count(Number of lines in the word list) :integer
#  name(Name of the word list)                  :string           indexed
#  processed                                    :boolean          default(FALSE), indexed
#  sensitive(Is the word list sensitive?)       :boolean
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#
# Indexes
#
#  index_word_lists_on_name       (name) UNIQUE
#  index_word_lists_on_processed  (processed)
#
FactoryBot.define do
  factory :word_list do
    name { Faker::Lorem.sentence }
    sensitive { false }
    processed { true }
    projects { [create(:project)] }

    after(:build) do |word_list|
      word_list.file.attach(
        io: Rails.root.join("spec/fixtures/word_lists/top-passwords.txt").open,
        filename: "top-passwords.txt"
      )
    end
  end
end
