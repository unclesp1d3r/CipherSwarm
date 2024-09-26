# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.array! @rule_lists, partial: "rule_lists/rule_list", as: :rule_list
