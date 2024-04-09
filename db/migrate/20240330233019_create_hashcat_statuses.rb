# frozen_string_literal: true

class CreateHashcatStatuses < ActiveRecord::Migration[7.1]
  def change
    create_table :hashcat_statuses do |t|
      t.belongs_to :task, null: false, foreign_key: true
      t.text :original_line, comment: "The original line from the hashcat output"
      t.string :session, comment: "The session name"
      t.datetime :time, comment: "The time of the status"
      t.integer :status, comment: "The status code"
      t.string :target, comment: "The target file"
      t.bigint :progress, array: true, comment: "The progress in percentage"
      t.bigint :restore_point, comment: "The restore point"
      t.bigint :recovered_hashes, array: true, comment: "The number of recovered hashes"
      t.bigint :recovered_salts, array: true, comment: "The number of recovered salts"
      t.bigint :rejected, comment: "The number of rejected hashes"
      t.datetime :time_start, comment: "The time the task started"
      t.datetime :estimated_stop, comment: "The estimated time of completion"

      t.timestamps
    end
  end
end
