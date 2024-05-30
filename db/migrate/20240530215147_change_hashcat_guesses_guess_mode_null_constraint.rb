# frozen_string_literal: true

class ChangeHashcatGuessesGuessModeNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hashcat_guesses, :guess_mode, false
  end
end
