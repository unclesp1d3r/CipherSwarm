# frozen_string_literal: true

class ChangeHashcatGuessesGuessBasePercentageNullConstraint < ActiveRecord::Migration[7.1]
  def change
    change_column_null :hashcat_guesses, :guess_base_percentage, false
  end
end
