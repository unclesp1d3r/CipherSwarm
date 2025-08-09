# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class AddCascadeFromCampaignToProjects < ActiveRecord::Migration[7.1]
  def change
    remove_foreign_key :campaigns, :projects
    add_foreign_key :campaigns, :projects, on_delete: :cascade
  end
end
