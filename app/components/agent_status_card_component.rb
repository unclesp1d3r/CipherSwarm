# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Component for displaying agent status information in a card layout.
# Shows agent name, status, hash rate, error count, and action buttons.
class AgentStatusCardComponent < ApplicationViewComponent
  include BootstrapIconHelper

  option :agent, required: true

  # Maps agent states to Bootstrap badge variants
  # @return [String] Bootstrap badge variant class
  def status_badge_variant
    case agent.state
    when "active"
      "success"
    when "pending"
      "secondary"
    when "stopped"
      "secondary"
    when "error"
      "danger"
    when "offline"
      "dark"
    else
      "secondary"
    end
  end

  # Returns additional CSS classes based on agent state
  # @return [String] Additional CSS classes for the card
  def card_classes
    classes = ["h-100"]
    classes << "border-danger" if agent.state == "error"
    classes.join(" ")
  end
end
