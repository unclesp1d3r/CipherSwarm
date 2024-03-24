# == Schema Information
#
# Table name: tasks
#
#  id                                                                 :bigint           not null, primary key
#  activity_timestamp(The timestamp of the last activity on the task) :datetime
#  start_date(The date and time that the task was started.)           :datetime         not null
#  status(Task status)                                                :integer          default("pending"), not null, indexed
#  created_at                                                         :datetime         not null
#  updated_at                                                         :datetime         not null
#  agent_id(The agent that the task is assigned to, if any.)          :bigint           indexed
#  operation_id(The attack that the task is associated with.)         :bigint           not null, indexed
#
# Indexes
#
#  index_tasks_on_agent_id      (agent_id)
#  index_tasks_on_operation_id  (operation_id)
#  index_tasks_on_status        (status)
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id)
#  fk_rails_...  (operation_id => operations.id)
#
class Task < ApplicationRecord
  belongs_to :attack, foreign_key: :operation_id, inverse_of: :tasks, touch: true
  belongs_to :agent, touch: true

  # The activity_timestamp attribute is used to track the last check-in time of the agent on the task.
  # If it has been more than 30 minutes since the last check-in, the task is considered to be inactive and should go back to the pending state.

  enum status: { pending: 0, running: 1, completed: 2, paused: 3, failed: 4, exhausted: 5 }
  scope :incomplete, -> { where.not(status: :completed) }

  def update_status
    if completed? || exhausted?
      return
    end
    if pending? && activity_timestamp.nil?
      # If the task is pending and the activity_timestamp is nil, the task hasn't been accepted by the agent yet,
      # so we should just return.
      return
    end
    if running? && activity_timestamp.nil?
      #  If the task is running and the activity_timestamp is nil, the task has probably just started, so we should return.
      return
    end
    if running? && activity_timestamp > 30.minutes.ago
      # If the agent is still running the task, but the last activity was more than 30 minutes ago, the task should be marked as pending.
      if agent.last_seen_at > 30.minutes.ago
        update(status: :failed)
      end
    end
    # If the task is pending and the last activity was less than 30 minutes ago, the task should be marked as running.
    if pending? && activity_timestamp <= 30.minutes.ago
      update(status: :running)
    end

    if running? && agent.last_seen_at <= 30.minutes.ago
      attack.update(status: :running)
    end

    # For now, we can also mark the attack as completed if it is a word list and there's no skip or limits.
    # At this point, there's no need to keep the attack running, since the word list is exhausted.
    if exhausted? && attack.dictionary?
      attack.update(status: :completed) if attack.tasks.exhausted.count == attack.tasks.count
    end
    hash_list.update_status
  end

  def hash_list
    attack.campaign.hash_list
  end
end
