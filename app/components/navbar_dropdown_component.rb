# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# NavbarDropdownComponent is a custom Ruby on Rails ViewComponent
# used to create a dropdown menu within a navigation bar.
#
# A dropdown menu can allow rendering of dynamic content
# and styling while supporting optional classes and icons.
#
# === Options:
# - :title (required) - Specifies the title of the dropdown; the title will be displayed as the trigger element for the dropdown.
# - :extra_classes (optional) - Additional CSS class definitions to style the component.
#   Defaults to nil if no extra classes are provided.
# - :icon (optional) - An optional icon identifier to render an icon alongside the dropdown title.
#   Defaults to nil if no icon is needed.
#
# This component inherits from ApplicationViewComponent, which allows
# it to utilize the component features and helpers included in the framework.
class NavbarDropdownComponent < ApplicationViewComponent
  option :title, required: true
  option :extra_classes, optional: true, default: nil
  option :icon, optional: true, default: nil
end
