# frozen_string_literal: true

class UpdateStatusJob < ApplicationJob
  queue_as :low_priority

  def perform(*_args)
    # Do something later
    Task.with_state(:running) do |task|
      task.abandon! if task.activity_timestamp >= 30.minutes.ago
    end

    Task.with_states(:running, :exhausted) do |task|
      task.delete_old_status
    end
  end
end
