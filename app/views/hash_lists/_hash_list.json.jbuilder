# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.extract! hash_list, :id, :name, :description, :file, :line_count, :sensitive, :hash_mode, :created_at, :updated_at
json.url hash_list_url(hash_list, format: :json)
json.file url_for(hash_list.file)
