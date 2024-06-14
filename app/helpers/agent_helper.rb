# frozen_string_literal: true

module AgentHelper
  def error_severity_to_css(severity)
    severities = {
      info: "default",
      warning: "warning",
      minor: "info",
      major: "primary",
      critical: "danger",
      fatal: "danger"
    }
    "table-#{severities[severity.to_sym]}"
  end
end
