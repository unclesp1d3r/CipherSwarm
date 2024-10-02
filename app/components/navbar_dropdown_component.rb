# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class NavbarDropdownComponent < ApplicationViewComponent
  option :title, required: true
  option :extra_classes, optional: true, default: nil
  option :icon, optional: true, default: nil
end
