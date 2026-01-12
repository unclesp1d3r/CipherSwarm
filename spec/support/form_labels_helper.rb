# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Helper module for form label lookups in system tests
# Centralizes label strings to make tests resilient to i18n and label customization changes
module FormLabelsHelper
  # Agent form labels
  module Agent
    # @return [String] the label for the custom_label field
    def self.custom_label
      I18n.t("simple_form.labels.agent.custom_label", default: "Custom label")
    end

    # @return [String] the label for the enabled checkbox
    def self.enabled
      I18n.t("simple_form.labels.agent.enabled", default: "Enabled")
    end

    # @return [String] the label for the user association field
    def self.user
      I18n.t("simple_form.labels.agent.user", default: "User")
    end

    # @return [String] the hint text for the user association field
    def self.user_hint
      I18n.t("simple_form.hints.agent.user", default: "The user that the agent is associated with")
    end

    # Advanced configuration labels
    module AdvancedConfiguration
      # @return [String] the label for the agent_update_interval field
      def self.agent_update_interval
        I18n.t("simple_form.labels.agent.advanced_configuration.agent_update_interval",
               default: "Agent update interval")
      end

      # @return [String] the label for the backend_device field
      def self.backend_device
        I18n.t("simple_form.labels.agent.advanced_configuration.backend_device",
               default: "Backend device")
      end

      # @return [String] the label for the opencl_devices field
      def self.opencl_devices
        I18n.t("simple_form.labels.agent.advanced_configuration.opencl_devices",
               default: "Opencl devices")
      end

      # @return [String] the label for the use_native_hashcat field
      def self.use_native_hashcat
        I18n.t("simple_form.labels.agent.advanced_configuration.use_native_hashcat",
               default: "Use native hashcat")
      end
    end
  end
end
