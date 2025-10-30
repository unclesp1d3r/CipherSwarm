# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "database_cleaner/active_record"
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:deletion)
  end

  # Default to transactions for speed
  config.before do
    DatabaseCleaner.strategy = :transaction
  end

  # System tests run in a separate browser process, so ensure committed data is visible
  config.before(:each, type: :system) do
    DatabaseCleaner.strategy = :truncation
  end

  # If a system spec explicitly disables JS, transactions are fine and faster
  config.before(:each, js: false, type: :system) do
    DatabaseCleaner.strategy = :transaction
  end

  config.around do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
