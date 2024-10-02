# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

#
# Module: AgentHelper
#
# This module provides helper methods for agent-related views.
#
# Methods:
# - error_severity_to_css(severity): Converts an error severity symbol to a corresponding CSS class string.
#   - Parameters:
#     - severity (Symbol): The severity level of the error. Expected values are :info, :warning, :minor, :major, :critical, or :fatal.
#   - Returns:
#     - String: A CSS class string prefixed with "table-" corresponding to the given severity.
module AgentHelper
  # Converts an error severity level to a corresponding CSS class.
  #
  # @param severity [String, Symbol] the severity level of the error.
  #   Expected values are: "info", "warning", "minor", "major", "critical", "fatal".
  # @return [String] the CSS class corresponding to the given severity level.
  #   The returned CSS class will be prefixed with "table-".
  #   For example, "info" will be converted to "table-default".
  def error_severity_to_css(severity)
    severities = {
      info: "default",
      warning: "warning",
      minor: "info",
      major: "primary",
      critical: "danger",
      fatal: "danger"
    }
    "table-#{severities.fetch(severity.to_sym, 'secondary')}"
  end
end
