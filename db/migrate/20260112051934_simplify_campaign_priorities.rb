# frozen_string_literal: true

# Migration to simplify campaign priorities from 7 levels to 3 levels
class SimplifyCampaignPriorities < ActiveRecord::Migration[8.0]
  def up
    # Map existing priorities to new 3-tier system:
    # flash_override (5), flash (4), immediate (3) → high (2)
    # urgent (2), priority (1), routine (0) → normal (0)
    # deferred (-1) → deferred (-1)

    execute <<-SQL.squish
      UPDATE campaigns
      SET priority = 2
      WHERE priority IN (3, 4, 5);
    SQL

    execute <<-SQL.squish
      UPDATE campaigns
      SET priority = 0
      WHERE priority IN (1, 2);
    SQL

    # Update column comment to reflect new values
    change_column_comment :campaigns, :priority,
      from: "-1: Deferred, 0: Routine, 1: Priority, 2: Urgent, 3: Immediate, 4: Flash, 5: Flash Override",
      to: "-1: Deferred, 0: Normal, 2: High"
  end

  def down
    # Restore to normal (0) as safe fallback for all non-deferred campaigns
    execute <<-SQL.squish
      UPDATE campaigns
      SET priority = 0
      WHERE priority = 2;
    SQL

    # Restore original column comment
    change_column_comment :campaigns, :priority,
      from: "-1: Deferred, 0: Normal, 2: High",
      to: "-1: Deferred, 0: Routine, 1: Priority, 2: Urgent, 3: Immediate, 4: Flash, 5: Flash Override"
  end
end
