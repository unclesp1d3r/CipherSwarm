# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

#
#
# This namespace contains tasks related to upgrading the application.
#
namespace :upgrade do
  desc "Run necessary tasks for upgrading to version 0.6.0"

  #
  # This Rake task is responsible for performing updates necessary for upgrading to version 0.6.0.
  # It updates the complexity values for MaskList records and stored complexity for Attack records.
  #
  # Steps performed:
  # 1. Updates the complexity value for all MaskList records in batches of 100.
  # 2. Updates the stored complexity for all Attack records with a complexity_value of 0 in batches of 100.
  #
  task update_060: :environment do
    puts "Starting update for version 0.6.0..."

    # Update complexity value for all MaskList records
    MaskList.find_each(batch_size: 100) do |mask_list|
      mask_list.update_complexity_value
      puts "Updated complexity value for MaskList ID: #{mask_list.id}"
    end

    # Update stored complexity for all Attack records
    Attack.where(complexity_value: 0).find_each(batch_size: 100) do |attack|
      attack.force_complexity_update
      puts "Updated stored complexity for Attack ID: #{attack.id}"
    end

    puts "Update for version 0.6.0 completed."
  end
end
