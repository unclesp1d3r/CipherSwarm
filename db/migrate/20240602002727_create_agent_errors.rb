# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class CreateAgentErrors < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_errors do |t|
      t.belongs_to :agent, null: false, foreign_key: true, comment: "The agent that caused the error"
      t.string :message, null: false, comment: "The error message"
      t.integer :severity, null: false, default: 0, comment: "The severity of the error"
      t.belongs_to :task, null: true, foreign_key: true, comment: "The task that caused the error, if any"
      t.jsonb :metadata, null: false, default: {}, comment: "Additional metadata about the error"
      t.timestamps
    end
  end
end
