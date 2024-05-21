# frozen_string_literal: true

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
