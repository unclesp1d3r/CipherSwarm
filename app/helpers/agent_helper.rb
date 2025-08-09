# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Converts an error severity level to a corresponding CSS class string.
#
# This method is used to map error severity levels to specific CSS class
# names for styling purposes. The method accepts a severity level as a
# string or symbol and returns a class name string prefixed with 'table-'.
#
# Defined severity mappings include:
# - :info -> 'table-default'
# - :warning -> 'table-warning'
# - :minor -> 'table-info'
# - :major -> 'table-primary'
# - :critical -> 'table-danger'
# - :fatal -> 'table-danger'
#
# If the severity level is not recognized, the default class 'table-secondary'
# will be returned.
#
# Parameters:
# - severity (String or Symbol): The severity level of the error.
#
# Returns:
# - (String): The CSS class string corresponding to the provided severity level.
module AgentHelper
  # Converts an error severity symbol to a corresponding CSS class string.
  #
  # The method maps a given error severity level to a specific CSS
  # class name prefixed by 'table-'. This mapping can then be used
  # for styling HTML elements based on the severity level of an error.
  #
  # If the provided severity does not match any of the predefined
  # severities, it defaults to using the CSS class 'table-secondary'.
  #
  # @param severity [String, Symbol] The severity level of the error,
  #   such as 'info', 'warning', 'critical', etc. The input is converted
  #   to a symbol for lookup.
  #
  # @return [String] Returns a CSS class string based on the provided severity,
  #   such as 'table-warning' or 'table-danger'. Defaults to 'table-secondary'
  #   if the severity is not recognized.
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
