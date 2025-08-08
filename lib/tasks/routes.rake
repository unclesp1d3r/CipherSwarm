# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

desc "Display all application routes"
task routes: :environment do
  puts `bundle exec rails routes`
end
