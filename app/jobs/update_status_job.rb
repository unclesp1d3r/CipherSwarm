class UpdateStatusJob < ApplicationJob
  queue_as :low_priority

  def perform(*args)
    # Do something later
    Task.with_state(:running) do |task|
      if task.activity_timestamp >= 30.minutes.ago
        task.abandon!
      end
    end

    Task.with_states(:running, :exhausted) do |task|
      task.delete_old_status
    end
  end
end
