# frozen_string_literal: true

class TaskObserver
  def after_accept_crack(task)
    task.update_activity_timestamp
  end

  def after_accept_status(task)
    task.update_activity_timestamp
  end
end
