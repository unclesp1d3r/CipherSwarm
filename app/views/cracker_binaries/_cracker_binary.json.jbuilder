# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.extract! cracker_binary, :id, :version, :active, :cracker_id, :created_at, :updated_at
json.url cracker_binary_url(cracker_binary, format: :json)
