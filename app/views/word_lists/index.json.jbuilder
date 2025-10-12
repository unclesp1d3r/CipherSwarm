# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.array! @word_lists, partial: "word_lists/word_list", as: :word_list
