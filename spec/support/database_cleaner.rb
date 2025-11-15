# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "database_cleaner/active_record"
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:deletion)
  end

  config.around do |example|
    # System tests use truncation strategy because they run in a separate browser process
    # which requires a different database connection, making transactions ineffective
    strategy = if example.metadata[:type] == :system
      :truncation
    else
      :transaction
    end

    DatabaseCleaner.strategy = strategy

    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
