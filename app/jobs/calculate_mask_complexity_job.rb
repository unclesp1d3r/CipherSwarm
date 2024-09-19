# frozen_string_literal: true

#
# The CalculateMaskComplexityJob class is responsible for calculating the complexity of masks
# defined in a MaskList. It inherits from ApplicationJob and processes jobs in the default queue.
#
# MASK_ELEMENT_COUNTS is a constant hash that maps mask elements to their respective counts:
# - "?a" => 95: All printable ASCII characters
# - "?d" => 10: Digits
# - "?l" => 26: Lowercase letters
# - "?u" => 26: Uppercase letters
# - "?s" => 33: Special characters
# - "?h" => 16: Hexadecimal characters
# - "?H" => 16: Hexadecimal characters
# - "?b" => 256: All bytes
#
# The custom_set_count method calculates the number of possible characters for custom sets
# within a given mask.
#
# The perform method calculates the mask complexity for a given MaskList identified by its ID.
# It retrieves the MaskList, processes its associated file, and calculates the total number of
# possible combinations for each mask in the file. The total combinations are then summed and
# stored in the MaskList's complexity_value attribute.
#
# @param mask_list_id [Integer] the ID of the MaskList to calculate complexity for
class CalculateMaskComplexityJob < ApplicationJob
  queue_as :default

  MASK_ELEMENT_COUNTS = {
    "?a" => 95, # All printable ASCII characters
    "?d" => 10, # Digits
    "?l" => 26, # Lowercase letters
    "?u" => 26, # Uppercase letters
    "?s" => 33, # Special characters
    "?h" => 16, # Hexadecimal characters
    "?H" => 16, # Hexadecimal characters
    "?b" => 256 # All bytes
  }.freeze

  # This method calculates the number of possible characters for custom sets
  def custom_set_count(mask, custom_sets)
    mask.scan(/\?\d/).reduce(1) do |product, custom|
      index = custom[1].to_i - 1
      product * (custom_sets[index] ? custom_sets[index].length : 1)
    end
  end

  # Performs the calculation of mask complexity for a given MaskList.
  #
  # @param mask_list_id [Integer] the ID of the MaskList to calculate complexity for
  #
  # The method retrieves the MaskList by its ID and processes its associated file.
  # It reads each line of the file, treating each line as a mask. For each mask, it calculates
  # the total number of possible combinations based on predefined element counts and custom sets.
  # The total combinations for all masks are then summed and stored in the MaskList's complexity_value attribute.
  def perform(mask_list_id)
    mask_list = MaskList.find(mask_list_id)
    return if mask_list.nil? || mask_list.file.nil?

    total_combinations = 0

    mask_list.file.open do |file|
      file.each_line do |line|
        mask = line.strip
        next if mask.empty?

        custom_sets = mask.scan(/\[.*?\]/).pluck(1..-2)
        mask.gsub!(/\[.*?\]/, "")

        combinations = mask.scan(/\?\w|./).reduce(1) do |product, element|
          product * (MASK_ELEMENT_COUNTS[element] || 1)
        end

        combinations *= custom_set_count(mask, custom_sets)

        total_combinations += combinations
      end
    end

    mask_list.update!(complexity_value: total_combinations)
  end
end
