class AddVersionIndexToCrackerBinary < ActiveRecord::Migration[7.1]
  def change
    add_index :cracker_binaries, :version
  end
end
