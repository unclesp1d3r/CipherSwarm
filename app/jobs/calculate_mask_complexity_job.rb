# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class CalculateMaskComplexityJob < ApplicationJob
  include TempStorageValidation

  queue_as :ingest
  discard_on ActiveRecord::RecordNotFound

  # Performs the calculation of mask complexity for a given MaskList.
  #
  # @param mask_list_id [Integer] the ID of the MaskList to calculate complexity for
  #
  # The method retrieves the MaskList by its ID and processes its associated file.
  # It reads each line of the file, treating each line as a mask. For each mask, it calculates
  # the total number of possible combinations based on the MaskCalculationMethods.calculate_mask_candidates method.
  # The total combinations for all masks are then summed and stored in the MaskList's complexity_value attribute.
  def perform(mask_list_id)
    mask_list = MaskList.find(mask_list_id)
    return if mask_list.nil? || mask_list.complexity_value != 0

    total_combinations = 0
    open_file(mask_list) do |file|
      file.each_line do |line|
        mask = line.strip
        next if mask.empty?

        total_combinations += MaskCalculationMethods.calculate_mask_candidates(mask)
      end
    end

    mask_list.update!(complexity_value: total_combinations)
  rescue IOError => e
    Rails.logger.error("Failed to process file for MaskList ##{mask_list_id}: #{e.message}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Failed to update MaskList ##{mask_list_id}: #{e.record.errors.full_messages.join(", ")}")
  end

  private

  def open_file(record, &)
    if record.respond_to?(:file_path) && record.file_path.present? && File.exist?(record.file_path)
      File.open(record.file_path, &)
    elsif record.respond_to?(:file) && record.file.attached?
      Rails.logger.warn("[CalculateMaskComplexity] Falling back to Active Storage blob.open for #{record.class.name}##{record.id} " \
                        "— file will be downloaded to /tmp. Ensure file_path is set for tusd uploads.")
      ensure_temp_storage_available!(record.file)
      record.file.open(&)
    else
      raise StandardError, "[CalculateMaskComplexity] No file found for #{record.class.name}##{record.id}"
    end
  end
end
