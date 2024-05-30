# frozen_string_literal: true

class ChangeAuditsAuditableIdToBigint < ActiveRecord::Migration[7.1]
  def change
    change_column :audits, :auditable_id, :bigint
  end
end
