# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# A component class that renders a status pill for representing the current state of an entity.
#
# This component displays a visual representation of a status (e.g., "running", "completed", "failed"), with
# an icon or spinner and corresponding visual styling based on the status.
#
# The rendered pill's background and icon are determined by the provided status, offering clear and
# accessible feedback to users.
#
# ==== Methods:
#
# - `indicator`: Generates the visual indicator for the status, which can either be a spinner
#   (in cases like "running") or a status-specific icon.
# - `status_class`: Maps a given status to its appropriate CSS class for styling the pill.
# - `status_icon`: Maps a given status to its associated icon name from Bootstrap icons.
# - `status_text`: Converts the status value to a human-readable text format.
#
# ==== Options:
#
# - `:status` [String]: A required option representing the status of the entity, which determines
#   the pill's visual appearance and text. Recognized statuses include "completed", "running", "paused",
#   "failed", "exhausted", and "pending".
#
# ==== Dependencies:
#
# This component depends on:
# - `ApplicationViewComponent`: The base class from which it inherits.
# - `BootstrapIconHelper`: A helper module providing methods to render Bootstrap icons.
class StatusPillComponent < ApplicationViewComponent
  include BootstrapIconHelper
  option :status, required: true

  def indicator
    if @status == "running"
      tag.span(class: "spinner-border spinner-border-sm") { tag.span("Running", class: "visually-hidden") }
    else
      icon(status_icon)
    end
  end

  def status_class
    case @status
    when "completed", "active", "exhausted"
      "text-bg-success"
    when "running"
      "text-bg-primary"
    when "paused", "pending"
      "text-bg-warning"
    when "failed", "error"
      "text-bg-danger"
    when "stopped"
      "text-bg-secondary"
    when "offline"
      "text-bg-dark"
    else
      "text-bg-default"
    end
  end

  def status_icon
    case @status
    when "completed", "active", "exhausted"
      "check-circle"
    when "running"
      "spinner"
    when "paused"
      "pause-circle"
    when "failed"
      "x-circle"
    when "pending"
      "clock"
    when "stopped"
      "stop-circle"
    when "error"
      "exclamation-triangle"
    when "offline"
      "wifi-off"
    else
      "question-circle"
    end
  end

  def status_text
    @status.humanize
  end
end
