# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class ChangeHashcatStatusesTargetNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hashcat_statuses, :target, false
  end
end
