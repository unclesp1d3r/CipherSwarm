# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.extract! rule_list, :id, :name, :description, :file, :line_count, :sensitive, :created_at, :updated_at
json.url rule_list_url(rule_list, format: :json)
json.file url_for(rule_list.file)
