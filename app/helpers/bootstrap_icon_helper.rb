# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# This module provides helper methods for generating Bootstrap icons, intended to be used in Rails views.
#
# It includes functionality for rendering a Bootstrap icon based on a boolean condition
# or a specific icon name. The icons are generated as HTML `<i>` elements with the
# appropriate CSS classes for Bootstrap icons.
module BootstrapIconHelper
  include ActionView::Helpers::TagHelper
  # Returns the appropriate Bootstrap icon based on the given boolean value.
  #
  # Parameters:
  # - boolean: A boolean value indicating whether the icon should be a check mark or a cross mark.
  #
  # Returns:
  # The HTML code for the corresponding Bootstrap icon.
  def boolean_icon(boolean)
    icon(boolean ? "check-square-fill" : "x-square-fill")
  end

  # Generates an HTML <i> tag with the specified Bootstrap icon class.
  #
  # @param name [String] The name of the Bootstrap icon.
  # @return [String] The HTML <i> tag with the specified Bootstrap icon class.
  def icon(name)
    tag.i class: "bi bi-#{name}"
  end
end
