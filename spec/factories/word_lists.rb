# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: word_lists
#
#  id                                           :bigint           not null, primary key
#  description(Description of the word list)    :text
#  line_count(Number of lines in the word list) :bigint
#  name(Name of the word list)                  :string           not null, indexed
#  processed                                    :boolean          default(FALSE), not null, indexed
#  sensitive(Is the word list sensitive?)       :boolean          not null
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#  creator_id(The user who created this list)   :bigint           indexed
#
# Indexes
#
#  index_word_lists_on_creator_id  (creator_id)
#  index_word_lists_on_name        (name) UNIQUE
#  index_word_lists_on_processed   (processed)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#
FactoryBot.define do
  factory :word_list do
    name
    sensitive { false }
    processed { true }
    projects { [Project.first || create(:project)] }

    after(:build) do |word_list|
      word_list.file.attach(
        io: Rails.root.join("spec/fixtures/word_lists/top-passwords.txt").open,
        filename: "top-passwords.txt"
      )
    end
  end
end
