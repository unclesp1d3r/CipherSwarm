# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Provides methods for calculating and managing attack complexity.
#
# This concern extracts complexity calculation logic from the Attack model to improve
# organization and testability.
#
# @example
#   attack.estimated_complexity
#   # => BigDecimal("1000000")
module AttackComplexityCalculation
  extend ActiveSupport::Concern

  # Complexity values for hashcat mask characters.
  # Maps mask placeholders to the number of characters they represent.
  COMPLEXITY_VALUES = {
    "?a" => 95,  # All printable ASCII characters
    "?d" => 10,  # Digits
    "?l" => 26,  # Lowercase letters
    "?u" => 26,  # Uppercase letters
    "?s" => 33,  # Special characters
    "?h" => 16,  # Hexadecimal characters (lowercase)
    "?H" => 16,  # Hexadecimal characters (uppercase)
    "?b" => 256  # All bytes
  }.freeze

  included do
    after_create_commit :update_stored_complexity
  end

  # Calculates the estimated complexity of an attack based on the attack mode.
  #
  # @return [BigDecimal] the estimated complexity value.
  def estimated_complexity
    case attack_mode
    when "dictionary"
      calculate_dictionary_complexity
    when "mask"
      calculate_mask_complexity
    else
      BigDecimal(0)
    end
  end

  # Forces an update to the complexity calculation of the attack and saves the changes.
  #
  # This method calls the `update_stored_complexity` method and saves the record.
  # Useful when there are changes in related entities that may affect the attack's complexity.
  def force_complexity_update
    update_stored_complexity
  end

  private

  # Calculates the complexity for dictionary attack mode.
  #
  # This method calculates the complexity based on the number of lines in the word list
  # and the rule list. If the rule list is empty, the complexity is equal to the number
  # of lines in the word list. If the rule list is not empty, the complexity is the product
  # of the number of lines in the word list and the number of lines in the rule list.
  # If increment mode is enabled, the complexity is multiplied by the size of the increment range.
  #
  # @return [BigDecimal] the calculated complexity value.
  def calculate_dictionary_complexity
    word_list_lines = word_list&.line_count || 0
    rule_list_lines = rule_list&.line_count || 0
    complexity = rule_list_lines.zero? ? word_list_lines : word_list_lines * rule_list_lines
    complexity *= increment_range_size if increment_mode
    complexity.to_d
  end

  # Calculates the complexity for mask attack mode.
  def calculate_mask_complexity
    return mask_list.complexity_value if mask_list.present?
    return BigDecimal("0.0") if mask.blank?
    MaskCalculationMethods.calculate_mask_candidates(mask)
  end

  ##
  # Converts the complexity value of an attack into a corresponding emoji representation.
  #
  # The returned emoji provides a qualitative indication of the attack's complexity:
  # - 🤷 for no complexity.
  # - 😃 for low complexity.
  # - 😐 for moderate complexity.
  # - 😟 for high complexity.
  # - 😳 for very high complexity.
  # - 😱 for extreme complexity beyond predefined thresholds.
  #
  # @return [String] An emoji representing the complexity level of the attack.
  def complexity_as_words
    case complexity_value
    when 0
      "🤷"
    when 1..1_000
      "😃"
    when 1_001..1_000_000
      "😐"
    when 1_000_001..1_000_000_000
      "😟"
    when 1_000_000_001..1_000_000_000_000
      "😳"
    else
      "😱"
    end
  end

  # Returns the complexity value for a given element.
  #
  # @param element [String] the element for which to calculate the complexity value.
  # @return [Integer] the complexity value for the given element.
  def complexity_value_for_element(element)
    COMPLEXITY_VALUES[element] || custom_charset_length(element) || 1
  end

  # Returns the length of the custom charset for the given element.
  #
  # @param element [String] the element for which to retrieve the custom charset length.
  # @return [Integer] the length of the custom charset.
  def custom_charset_length(element)
    case element
    when "?1" then custom_charset_1.length
    when "?2" then custom_charset_2.length
    when "?3" then custom_charset_3.length
    when "?4" then custom_charset_4.length
    else
      0
    end
  end

  # Calculates the size of the increment range.
  #
  # @return [Integer] the size of the increment range.
  def increment_range_size
    (increment_minimum..increment_maximum).to_a.size
  end

  # Updates the stored complexity value of the attack.
  #
  # This method calculates the estimated complexity of the attack
  # and updates the `complexity_value` attribute with the calculated value.
  #
  # @return [Boolean] true if the record was successfully updated, false otherwise.
  def update_stored_complexity
    update(complexity_value: estimated_complexity)
  end
end
