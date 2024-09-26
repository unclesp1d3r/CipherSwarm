# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

json.extract! attack, :id, :created_at, :updated_at
json.url campaign_attack_url([attack.campaign, attack], format: :json)
