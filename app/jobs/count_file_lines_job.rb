# frozen_string_literal: true

class CountFileLinesJob < ApplicationJob
  queue_as :high
  retry_on ActiveStorage::FileNotFoundError, wait: :polynomially_longer, attempts: 10
  retry_on ActiveRecord::RecordNotFound, wait: :polynomially_longer, attempts: 2

  # Performs the job to count the number of lines in a file associated with a given list.
  #
  # @param args [Array] The arguments passed to the job.
  # @return [void]
  def perform(*args)
    id = args.first
    type = args.second
    klass = type.constantize
    list = klass.find(id)
    return if list.nil?
    return if list.processed? || list.file.nil?

    list.file.open do |file|
      count = 0
      file.each_line do |line|
        count += 1
        line.chomp!
      end
      list.line_count = count
    end
    list.processed = true
    list.save!
  end
end
