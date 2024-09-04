# frozen_string_literal: true

# CountFileLinesJob is a background job that counts the number of lines in a file
# associated with a given record and updates the record with the line count.
#
# This job retries on ActiveStorage::FileNotFoundError and ActiveRecord::RecordNotFound
# with polynomially increasing wait times.
class CountFileLinesJob < ApplicationJob
  queue_as :high
  retry_on ActiveStorage::FileNotFoundError, wait: :polynomially_longer, attempts: 10
  retry_on ActiveRecord::RecordNotFound, wait: :polynomially_longer, attempts: 2

  # Performs the job.
  #
  # @param id [Integer] the ID of the record to process
  # @param type [String] the class name of the record to process
  def perform(id, type)
    klass = type.constantize
    list = klass.find(id)
    return if list.nil?
    return if list.processed? || list.file.nil?

    list.file.open do |file|
      count = file.each_line.count
      list.update!(line_count: count, processed: true)
    end
  end
end
