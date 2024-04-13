# frozen_string_literal: true

json.array! @word_lists, partial: "word_lists/word_list", as: :word_list
