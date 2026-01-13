# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Helper module for testing migrations
module MigrationHelper
  # Runs a migration up
  #
  # @param migration [ActiveRecord::Migration] the migration class to run
  # @return [void]
  def migrate_up(migration)
    # Suppress migration output for cleaner test results
    ActiveRecord::Migration.suppress_messages do
      migration.migrate(:up)
    end
  end

  # Runs a migration down
  #
  # @param migration [ActiveRecord::Migration] the migration class to run
  # @return [void]
  def migrate_down(migration)
    # Suppress migration output for cleaner test results
    ActiveRecord::Migration.suppress_messages do
      migration.migrate(:down)
    end
  end
end

RSpec.configure do |config|
  config.include MigrationHelper, type: :migration
end
