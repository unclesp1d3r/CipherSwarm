# frozen_string_literal: true

class MoveHashListHashModeToHashType < ActiveRecord::Migration[7.1]
  def down
    add_column :hash_lists, :hash_mode, :integer, null: false, default: 0
    HashList.find_each do |hash_list|
      hash_list.update!(hash_mode: hash_list.hash_type.hashcat_mode)
    end
    remove_reference :hash_lists, :hash_type, foreign_key: true
  end

  def up
    add_reference :hash_lists, :hash_type, foreign_key: true, null: true
    hash_types = HashList.distinct.pluck(:hash_mode).map do |hash_mode|
      HashType.create!(hashcat_mode: hash_mode, name: HashList.hash_modes[hash_mode], enabled: true)
    end
    hash_types.each do |hash_type|
      HashList.where(hash_mode: hash_type.hashcat_mode).update_all(hash_type_id: hash_type.id) # rubocop:disable Rails/SkipsModelValidations
    end
    remove_column :hash_lists, :hash_mode
  end
end
