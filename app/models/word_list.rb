# frozen_string_literal: true

# WordList is a model that represents a list of words for use in dictionary attacks in the CipherSwarm application.
# It includes the AttackResource module, which provides additional functionality
# related to attack resources.
#
# @see AttackResource
#
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
class WordList < ApplicationRecord
  include AttackResource
end
