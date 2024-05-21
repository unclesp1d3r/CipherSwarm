# frozen_string_literal: true

# Helper methods for generating the sidebar and navbar navigation.
module NavHelper
  # Generates a sidebar link with the specified name, path, and icon.
  #
  # @param name [String] The name of the link.
  # @param path [String] The path of the link.
  # @param icon [String, nil] The icon to display before the link name, or nil if no icon is needed.
  # @return [String] The HTML code for the sidebar link.
  def sidebar_link(name, path, icon)
    class_name = current_page?(path) ? "active" : ""
    content_tag :li, class: "nav-item" do
      link_to path, class: "nav-link #{class_name}" do
        if icon.nil?
          name
        else
          icon(icon) + name
        end
      end
    end
  end
end
