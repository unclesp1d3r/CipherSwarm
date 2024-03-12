class AddSeparatorToHashList < ActiveRecord::Migration[7.1]
  def change
    add_column :hash_lists, :separator, :string, default: ':', null: false, limit: 1,
               comment: 'Separator used in the hash list file to separate the hash from the password or other metadata. Default is ":".'
  end
end
