class UpdateStatusJob < ApplicationJob
  queue_as :low_priority

  def perform(*args)
    # Do something later
    Task.where.not(status: :completed).each do |task|
      task.update_status
    end

    HashList.all.each do |hash_list|
      hash_list.update_status
    end
  end
end
