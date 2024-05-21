# frozen_string_literal: true

class StatusPillComponent < ApplicationViewComponent
  include BootstrapIconHelper
  option :status, required: true

  def status_class
    case @status
    when "completed"
      "text-bg-success"
    when "running"
      "text-bg-primary"
    when "paused"
      "text-bg-warning"
    when "failed"
      "text-bg-danger"
    when "exhausted"
      "text-bg-success"
    when "pending"
      "text-bg-secondary"
    else
      "text-bg-default"
    end
  end

  def status_icon
    case @status
    when "completed"
      "check-circle"
    when "running"
      "spinner"
    when "paused"
      "pause-circle"
    when "failed"
      "times-circle"
    when "exhausted"
      "check-circle"
    when "pending"
      "clock"
    else
      "question-circle"
    end
  end

  def status_text
    @status.humanize
  end
end
