# frozen_string_literal: true

class NavbarDropdownComponent < ApplicationViewComponent
  option :title, required: true
  option :extra_classes, optional: true, default: nil
  option :icon, optional: true, default: nil
end
