# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "database_cleaner/active_record"
RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:deletion)
  end

  config.around do |example|
    strategy = :transaction

    if example.metadata[:type] == :system
      strategy = example.metadata.fetch(:js, true) ? :truncation : :transaction
    end

    DatabaseCleaner.strategy = strategy

    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
