# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# A name factory that generates a unique name for each instance
# This should reduce the number of failed tests due to unique constraints
FactoryBot.define do
  sequence(:name) { "#{Faker::Lorem.words(number: 3).join(' ')} #{_1}" }
end
