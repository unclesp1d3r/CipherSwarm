# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# ProgressBarComponent is a UI component that renders a progress bar
# to visually display the current state of progress relative to a total.
#
# Options:
# - `percentage`: (required) A numerical value representing the progress
#      completion percentage. This value determines the width of the progress bar.
# - `label`: (optional, defaults to "Label") A descriptive string
#      that represents the label for the progress bar. This is used to improve
#      accessibility by providing an ARIA label.
#
# Output:
# - Generates a div element with the class `progress` to represent the progress container.
# - Inside the container, another div element with the class `progress-bar` is created.
#      The width of this inner div is dynamically set based on the percentage.
# - ARIA accessibility attributes are included, such as `aria-valuenow`,
#      `aria-valuemin`, `aria-valuemax`, and `aria-label`.
#
# Features:
# - Uses Bootstrap-compatible classes like `progress` and `progress-bar`.
# - Applies inline styles and tooltip attributes for percentage display.
# - Ensures proper accessibility support with ARIA attributes for screen readers.
#
# Behavior:
# - The percentage value is formatted as a percentage string with
#      two decimal places before being applied.
# - The tooltip displays the percentage value for additional context.
class ProgressBarComponent < ApplicationViewComponent
  option :percentage, required: true
  option :label, default: proc { "Label" }

  def call
    percentage_number = number_to_percentage(@percentage, precision: 2)
    tag.div class: "progress",
            role: "progressbar",
            "aria-label": @label,
            "aria-valuenow": 0,
            "aria-valuemin": 0,
            "aria-valuemax": 100 do
      tag.div nil, class: "progress-bar",
                   style: "width: #{percentage_number}",
                   role: "progressbar",
                   "aria-valuenow": @percentage,
                   "aria-valuemin": 0,
                   "aria-valuemax": 100,
                   "aria-label": "Progress bar",
                   "data-bs-toggle": "tooltip",
                   "data-bs-placement": :top,
                   title: "#{percentage_number}"
    end
  end
end
