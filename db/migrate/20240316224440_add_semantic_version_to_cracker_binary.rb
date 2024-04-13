# frozen_string_literal: true

class AddSemanticVersionToCrackerBinary < ActiveRecord::Migration[7.1]
  def change
    add_column :cracker_binaries, :major_version, :integer, null: true,
                                                            comment: "The major version of the cracker binary."
    add_column :cracker_binaries, :minor_version, :integer, null: true,
                                                            comment: "The minor version of the cracker binary."
    add_column :cracker_binaries, :patch_version, :integer, null: true,
                                                            comment: "The patch version of the cracker binary."
    add_column :cracker_binaries, :prerelease_version, :string, null: true, default: "",
                                                                comment: "The prerelease version of the cracker binary."
  end
end
