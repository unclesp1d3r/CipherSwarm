# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Determines the CSS class for the given attack based on the state of the attack.
#
# This method is used to map the state of an attack to a corresponding
# CSS class string to facilitate visual representation in the UI.
#
# The mapping is as follows:
# - "completed": "success"
# - "running": "primary"
# - "paused": "warning"
# - "failed": "danger"
# - "exhausted": "success"
# - "pending": "secondary"
# - Any other state: "default"
#
# @param attack [Object] the attack object. It should respond to the `state` method
#   to provide its current state, otherwise the method will return "default".
#
# @return [String] the CSS class string corresponding to the attack's state.
#   If the attack does not have a recognized state or does not respond to `state`,
#   the method will return "default".
#
module AttackHelper
  # Determines the CSS class for the given attack based on its state.
  #
  # @param attack [Object] the attack object which contains the state attribute.
  # @return [String] the CSS class corresponding to the attack's state.
  #   - "completed" -> "success"
  #   - "running" -> "primary"
  #   - "paused" -> "warning"
  #   - "failed" -> "danger"
  #   - "exhausted" -> "success"
  #   - "pending" -> "secondary"
  #   - any other state -> "default"
  def attack_status_class(attack)
    return "default" unless attack.respond_to?(:state)

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
