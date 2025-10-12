# frozen_string_literal: true

class RemoveRedundantHashcatGuessesIndex < ActiveRecord::Migration[7.2]
  def change
    remove_index :hashcat_guesses, name: "index_hashcat_guesses_on_hashcat_status_id"
  end
end
