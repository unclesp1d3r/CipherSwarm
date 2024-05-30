# frozen_string_literal: true

class ChangeHashcatGuessesGuessModPercentageNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hashcat_guesses, :guess_mod_percentage, false
  end
end
