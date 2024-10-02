# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.array! @hash_lists, partial: "hash_lists/hash_list", as: :hash_list
