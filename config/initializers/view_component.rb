# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Configure ViewComponent preview paths
Rails.application.config.to_prepare do
  if defined?(ViewComponent) && Rails.application.config.respond_to?(:view_component)
    Rails.application.config.view_component.preview_paths ||= []
    Rails.application.config.view_component.preview_paths << Rails.root.join("app/components") unless Rails.application.config.view_component.preview_paths.include?(Rails.root.join("app/components"))
  end
end

ActiveSupport.on_load(:view_component) do
  # Extend your preview controller to support authentication and other
  # application-specific stuff
  #
  # Rails.application.config.to_prepare do
  #   ViewComponentsController.class_eval do
  #     include Authenticated
  #   end
  # end
  #
  # Contrib extensions commented out until gem compatibility is resolved
  # Make it possible to store previews in sidecar folders
  # See https://github.com/palkan/view_component-contrib#organizing-components-or-sidecar-pattern-extended
  # ViewComponent::Preview.extend ViewComponentContrib::Preview::Sidecarable
  # Enable `self.abstract_class = true` to exclude previews from the list
  # ViewComponent::Preview.extend ViewComponentContrib::Preview::Abstract
end
