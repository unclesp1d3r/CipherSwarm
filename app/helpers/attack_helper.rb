# frozen_string_literal: true

module AttackHelper
  def attack_status_class(attack)
    case attack.state
    when "completed"
      "success"
    when "running"
      "primary"
    when "paused"
      "warning"
    when "failed"
      "danger"
    when "exhausted"
      "success"
    when "pending"
      "secondary"
    else
      "default"
    end
  end
end
