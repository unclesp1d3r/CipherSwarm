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
# - ActiveStorage::FileNotFoundError: Retries up to 10 times with exponentially increasing wait times.
# - ActiveRecord::RecordNotFound: Retries up to 2 times with exponentially increasing wait times.
#
# @example Enqueue the job
#   CountFileLinesJob.perform_later(record_id, 'RecordClassName')
#
# @param id [Integer] the ID of the record to process
# @param type [String] the class name of the record to process
class CountFileLinesJob < ApplicationJob
  queue_as :ingest
  retry_on ActiveStorage::FileNotFoundError, wait: :polynomially_longer, attempts: 3
  retry_on ActiveRecord::RecordNotFound, wait: :polynomially_longer, attempts: 2

  # Performs the job to count the number of lines in a file associated with a given record.
  #
  # @param id [Integer] the ID of the record to process
  # @param type [String] the class name of the record to process
  # @return [void]
  #
  # This method finds the record by its ID and type, checks if it has already been processed or if the file is missing,
  # and if not, it opens the file, counts the number of lines, and updates the record with the line count and marks it as processed.
  def perform(id, type)
    klass = type.constantize
    record = klass.find_by(id: id)
    return if record.nil?
    return if record.processed? || record.file.nil?

    record.file.open do |file|
      count = file.each_line.count
      record.update!(line_count: count, processed: true)
      Rails.logger.info "Counted #{count} lines in #{record.file.filename}"
    end
  end
end
