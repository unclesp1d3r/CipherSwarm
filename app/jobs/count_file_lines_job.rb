class CountFileLinesJob < ApplicationJob
  queue_as :default
  retry_on ActiveStorage::FileNotFoundError, wait: 5.seconds, attempts: 3

  def perform(*args)
    id = args.first
    type = args.second
    if type == "RuleList"
      list = RuleList.find(id)
    else
      list = WordList.find(id)
    end
    unless list.processed? || list.file.nil?
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
