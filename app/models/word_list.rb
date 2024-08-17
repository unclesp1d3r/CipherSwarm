# frozen_string_literal: true

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
#
# Indexes
#
#  index_word_lists_on_name       (name) UNIQUE
#  index_word_lists_on_processed  (processed)
#
class WordList < ApplicationRecord
  include AttackResource
end
