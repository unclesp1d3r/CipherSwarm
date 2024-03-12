class CountFileLinesJob < ApplicationJob
  queue_as :default

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
