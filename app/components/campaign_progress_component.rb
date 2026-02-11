# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# CampaignProgressComponent renders a composite progress display for campaigns/attacks.
#
# It combines a progress bar, percentage text, ETA text, and a status badge into a
# single reusable component suitable for dashboards and monitoring views.
#
# == Options
# - percentage: (Float, required) The completion percentage for the progress bar.
# - status: (String, required) The state of the attack (completed, running, paused, failed, exhausted, pending).
# - eta: (Time, optional) Estimated completion time. When nil, displays terminal state label or "N/A".
# - label: (String, optional, default: "Progress") Accessible label for the progress bar.
#
# == Example
#   render(CampaignProgressComponent.new(
#     percentage: attack.progress_percent,
#     status: attack.state,
#     eta: attack.estimated_completion_at,
#     label: "Attack Progress"
#   ))
#
# == Helpers
# - status_class: Maps status to Bootstrap badge classes.
# - status_icon: Maps status to Bootstrap icon names.
# - formatted_eta: Formats ETA text or displays terminal state labels (Completed, Failed, Exhausted).
# - formatted_percentage: Formats percentage to 2 decimal places.
class CampaignProgressComponent < ApplicationViewComponent
  include BootstrapIconHelper
  include ActionView::Helpers::DateHelper

  option :percentage, required: true
  option :status, required: true
  option :eta, default: proc { nil }
  option :label, default: proc { "Progress" }

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
      "arrow-repeat"
    when "paused"
      "pause-circle-fill"
    when "failed"
      "x-circle"
    when "exhausted"
      "check-circle"
    when "pending"
      "clock"
    else
      "question-circle"
    end
  end

  def formatted_eta
    if @eta.blank?
      case @status
      when "completed"
        "Completed"
      when "failed"
        "Failed"
      when "exhausted"
        "Exhausted"
      when "pending", "running", "paused"
        "Calculating\u2026"
      else
        "N/A"
      end
    else
      "ETA: ~#{distance_of_time_in_words(Time.current, @eta)}"
    end
  end

  def formatted_percentage
    Kernel.format("%.2f%%", @percentage)
  end
end
