# frozen_string_literal: true

class AddCoveringIndexForStatusTrim < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :hashcat_statuses, %i[task_id time id],
              order: { time: :desc, id: :desc },
              name: "index_hashcat_statuses_on_task_time_id_desc",
              algorithm: :concurrently

    # Tune autovacuum for high-churn table: status rows are inserted frequently
    # (~360/hour per task) and trimmed/deleted regularly. Lower thresholds trigger
    # autovacuum after 1% dead tuples instead of the default 20%.
    execute <<~SQL.squish
      ALTER TABLE hashcat_statuses SET (
        autovacuum_vacuum_scale_factor = 0.01,
        autovacuum_analyze_scale_factor = 0.02
      );
    SQL
  end

  def down
    remove_index :hashcat_statuses, name: "index_hashcat_statuses_on_task_time_id_desc",
                                    algorithm: :concurrently

    execute <<~SQL.squish
      ALTER TABLE hashcat_statuses RESET (
        autovacuum_vacuum_scale_factor,
        autovacuum_analyze_scale_factor
      );
    SQL
  end
end
