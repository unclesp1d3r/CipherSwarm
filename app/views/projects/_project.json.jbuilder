# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.extract! project, :id, :name, :description, :users, :created_at, :updated_at
json.url project_url(project, format: :json)
