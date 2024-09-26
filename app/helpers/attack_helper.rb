# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

#
# The AttackHelper module provides utility methods for handling attack-related
# operations in the application.
#
# Methods:
# - attack_status_class(attack): Determines the CSS class to be applied based on
#   the state of the given attack object.
#
#   Parameters:
#   - attack: An object representing an attack, which must respond to the `state`
#     method.
#
#   Returns:
#   - A string representing the CSS class corresponding to the attack's state.
#     Possible return values are:
#     - "success" for "completed" and "exhausted" states
#     - "primary" for "running" state
#     - "warning" for "paused" state
#     - "danger" for "failed" state
#     - "secondary" for "pending" state
#     - "default" for any other state
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
