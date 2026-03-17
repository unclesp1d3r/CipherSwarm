# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

#
# CountFileLinesJob is a background job that counts the number of lines in a file
# associated with a given record and updates the record with the line count.
#
# This job is queued with high priority and will retry on specific errors.
#
# Retries:
# - ActiveStorage::FileNotFoundError: Retries up to 3 times with exponentially increasing wait times.
#
# Discards:
# - ActiveRecord::RecordNotFound: Discards the job if the record no longer exists.
#
# @example Enqueue the job
#   CountFileLinesJob.perform_later(record_id, 'RecordClassName')
#
# @param id [Integer] the ID of the record to process
# @param type [String] the class name of the record to process
class CountFileLinesJob < ApplicationJob
  include TempStorageValidation

  # Raised when the type argument is not in ALLOWED_TYPES.
  class InvalidTypeError < ArgumentError; end

  ALLOWED_TYPES = %w[WordList RuleList MaskList HashList].freeze

  queue_as :ingest
  retry_on ActiveStorage::FileNotFoundError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound
  discard_on InvalidTypeError

  # Performs the job to count the number of lines in a file associated with a given record.
  #
  # @param id [Integer] the ID of the record to process
  # @param type [String] the class name of the record to process
  # @return [void]
  #
  # This method finds the record by its ID and type, checks if it has already been processed or if the file is missing,
  # and if not, it opens the file, counts the number of lines, and updates the record with the line count and marks it as processed.
  def perform(id, type)
    unless ALLOWED_TYPES.include?(type)
      raise InvalidTypeError, "[CountFileLinesJob] Invalid type '#{type}' - must be one of #{ALLOWED_TYPES.join(', ')}"
    end

    klass = type.constantize
    record = klass.find_by(id: id)
    return if record.nil?
    return if record.processed?

    count_lines(record) do |count|
      record.update!(line_count: count, processed: true)
      Rails.logger.info "[CountFileLines] Counted #{count} lines for #{record.class.name}##{record.id}"
    end
  end

  private

  def count_lines(record)
    open_record_file(record) do |file|
      count = file.each_line.count
      yield count
    end
  end

  def open_record_file(record, &)
    if record.file_path.present? && File.exist?(record.file_path)
      File.open(record.file_path, &)
    elsif record.file.attached?
      ensure_temp_storage_available!(record.file)
      record.file.open(&)
    end
  end
end
