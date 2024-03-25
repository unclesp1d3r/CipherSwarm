class CountFileLinesJob < ApplicationJob
  queue_as :default

  # Performs the job of counting the number of lines in a file associated with a WordList.
  #
  # @param args [Array] The arguments passed to the job.
  # @return [void]
  def perform(*args)
    id = args.first
    list = WordList.find(id)
    unless list.processed?
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
end
