# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Renders a Bootstrap 5 toast notification with auto-hide behavior.
#
# Uses Stimulus toast controller to auto-dismiss after a configurable delay
# and remove the element from the DOM once hidden.
#
# == Options
# - message: (String, required) The notification text to display.
# - variant: (String, optional, default: "success") Bootstrap color variant
#   (success, danger, warning, info).
class ToastNotificationComponent < ApplicationViewComponent
  option :message, required: true
  option :variant, default: proc { "success" }

  def icon_name
    case @variant
    when "success"
      "check-circle-fill"
    when "danger"
      "exclamation-triangle-fill"
    when "warning"
      "exclamation-triangle-fill"
    when "info"
      "info-circle-fill"
    else
      "info-circle-fill"
    end
  end

  def border_class
    "border-#{@variant}"
  end
end
