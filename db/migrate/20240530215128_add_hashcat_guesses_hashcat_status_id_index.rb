# frozen_string_literal: true

class AddHashcatGuessesHashcatStatusIdIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :hashcat_guesses, %w[hashcat_status_id], name: :index_hashcat_guesses_hashcat_status_id, unique: true
  end
end
