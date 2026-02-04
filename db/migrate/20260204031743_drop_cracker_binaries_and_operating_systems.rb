# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Removes unused Cracker Binaries and Operating Systems feature.
# These tables were added to support managing hashcat versions but
# the functionality was never fully developed and is not being used.
#
# Note: This does NOT affect the Agent.operating_system enum which
# tracks which OS an agent is running on - that is a separate feature.
class DropCrackerBinariesAndOperatingSystems < ActiveRecord::Migration[8.0]
  def up
    # Drop join table first (depends on both other tables)
    drop_table :cracker_binaries_operating_systems, if_exists: true

    # Drop the main tables
    drop_table :cracker_binaries, if_exists: true
    drop_table :operating_systems, if_exists: true
  end

  def down
    create_table :operating_systems do |t|
      t.string :name, null: false
      t.string :cracker_command, null: false
      t.timestamps
      t.index :name, unique: true
    end

    create_table :cracker_binaries do |t|
      t.string :version, null: false
      t.boolean :active, default: false, null: false
      t.bigint :major_version
      t.bigint :minor_version
      t.bigint :patch_version
      t.timestamps
      t.index :version
    end

    create_table :cracker_binaries_operating_systems, id: false do |t|
      t.bigint :cracker_binary_id, null: false
      t.bigint :operating_system_id, null: false
      t.index :cracker_binary_id
    end
  end
end
