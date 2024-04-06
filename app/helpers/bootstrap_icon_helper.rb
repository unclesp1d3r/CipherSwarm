# frozen_string_literal: true

module BootstrapIconHelper
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
    content_tag :i, nil, class: "bi bi-#{name}"
  end
end
