# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddCascadeToTask < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :hashcat_statuses, :tasks
    add_foreign_key :hashcat_statuses, :tasks, on_delete: :cascade

    remove_foreign_key :hashcat_guesses, :hashcat_statuses
    add_foreign_key :hashcat_guesses, :hashcat_statuses, on_delete: :cascade

    remove_foreign_key :device_statuses, :hashcat_statuses
    add_foreign_key :device_statuses, :hashcat_statuses, on_delete: :cascade
  end
end
