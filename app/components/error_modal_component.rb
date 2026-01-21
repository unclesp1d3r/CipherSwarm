# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# ErrorModalComponent renders a Bootstrap modal with details about an AgentError.
#
# It displays severity, timestamp, message, metadata, and an optional task link in
# a consistent modal layout using Railsboot::ModalComponent slots.
#
# == Options
# - error: (AgentError, required) The error record to display.
# - modal_id: (String, required) The DOM id for the modal element.
# - size: (String, optional, default: "lg") Bootstrap modal size.
#
# == Example
#   <button class="btn btn-outline-danger" data-bs-toggle="modal" data-bs-target="#error-42">
#     View Error
#   </button>
#   <%= render(ErrorModalComponent.new(error: error, modal_id: "error-42")) %>
#
# == Helpers
# - severity_badge_class: Maps severity to Bootstrap badge classes.
# - severity_icon: Maps severity to Bootstrap icon names.
# - formatted_timestamp: Formats created_at as "MMM DD, YYYY HH:MM AM/PM".
# - task_link: Returns a link to the associated attack or plain text if unavailable.
class ErrorModalComponent < ApplicationViewComponent
  include BootstrapIconHelper

  option :error, required: true
  option :modal_id, required: true
  option :size, default: proc { "lg" }

  def severity_badge_class
    case @error.severity
    when "info"
      "text-bg-info"
    when "warning"
      "text-bg-warning"
    when "minor"
      "text-bg-warning"
    when "major"
      "text-bg-danger"
    when "critical"
      "text-bg-danger"
    when "fatal"
      "text-bg-dark"
    else
      "text-bg-secondary"
    end
  end

  def severity_icon
    case @error.severity
    when "info"
      "info-circle"
    when "warning"
      "exclamation-triangle"
    when "minor"
      "exclamation-circle"
    when "major"
      "exclamation-triangle-fill"
    when "critical"
      "x-octagon"
    when "fatal"
      "x-octagon-fill"
    else
      "question-circle"
    end
  end

  def formatted_timestamp
    return "N/A" if @error.created_at.blank?

    @error.created_at.strftime("%b %d, %Y %I:%M %p")
  end

  def task_link
    return if @error.task_id.blank?

    task = Task.find_by(id: @error.task_id)
    return "Task ##{@error.task_id}" if task.blank?

    attack = task.attack
    campaign = attack&.campaign

    return "Task ##{@error.task_id}" if campaign.blank? || attack.blank?

    link_to("View Task ##{@error.task_id}", campaign_attack_path(campaign, attack))
  rescue StandardError
    "Task ##{@error.task_id}"
  end
end
