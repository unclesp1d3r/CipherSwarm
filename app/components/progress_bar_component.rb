# frozen_string_literal: true

class ProgressBarComponent < ViewComponent::Base
  def initialize(percentage:, label: "Label")
    @percentage = percentage
    @label = label
  end

  def call
    tag.div class: "progress",
            role: "progressbar",
            "aria-label": @label,
            "aria-valuenow": 0,
            "aria-valuemin": 0,
            "aria-valuemax": 100 do
      tag.div nil, class: "progress-bar",
                   style: "width: #{number_to_percentage(@percentage, precision: 2)}",
                   role: "progressbar",
                   "aria-valuenow": @percentage,
                   "aria-valuemin": 0,
                   "aria-valuemax": 100,
                   "aria-label": "Progress bar",
                   "data-bs-toggle": "tooltip",
                   "data-bs-placement": :top,
                   title: "#{number_to_percentage(@percentage, precision: 2)}"
    end
  end
end
