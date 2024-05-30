# frozen_string_literal: true

# == Schema Information
#
# Table name: hashcat_guesses
#
#  id                                                                     :bigint           not null, primary key
#  guess_base(The base value used for the guess (for example, the mask))  :string           not null
#  guess_base_count(The number of times the base value was used)          :bigint           not null
#  guess_base_offset(The offset of the base value)                        :bigint           not null
#  guess_base_percentage(The percentage completion of the base value)     :decimal(, )      not null
#  guess_mod(The modifier used for the guess (for example, the wordlist)) :string
#  guess_mod_count(The number of times the modifier was used)             :bigint           not null
#  guess_mod_offset(The offset of the modifier)                           :bigint           not null
#  guess_mod_percentage(The percentage completion of the modifier)        :decimal(, )      not null
#  guess_mode(The mode used for the guess)                                :integer          not null
#  created_at                                                             :datetime         not null
#  updated_at                                                             :datetime         not null
#  hashcat_status_id                                                      :bigint           not null, indexed, indexed
#
# Indexes
#
#  index_hashcat_guesses_hashcat_status_id     (hashcat_status_id) UNIQUE
#  index_hashcat_guesses_on_hashcat_status_id  (hashcat_status_id)
#
# Foreign Keys
#
#  fk_rails_...  (hashcat_status_id => hashcat_statuses.id)
#
class HashcatGuess < ApplicationRecord
  belongs_to :hashcat_status
  validates :guess_base, presence: true
  validates :guess_base_count, presence: true, numericality: { only_integer: true }
  validates :guess_base_offset, presence: true, numericality: { only_integer: true }
  validates :guess_base_percentage, presence: true, numericality: true
  validates :guess_mod_count, presence: true, numericality: { only_integer: true }
  validates :guess_mod_offset, presence: true, numericality: { only_integer: true }
  validates :guess_mod_percentage, presence: true, numericality: true
  validates :guess_mode, presence: true, numericality: { only_integer: true }

  def guess_base_percent
    guess_base_percentage
  end

  def guess_base_percent=(value)
    self.guess_base_percentage = value
  end

  def guess_mod_percent
    guess_mod_percentage
  end

  def guess_mod_percent=(value)
    self.guess_mod_percentage = value
  end
end
