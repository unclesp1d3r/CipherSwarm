# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

class CampaignProgressComponentPreview < ApplicationViewComponentPreview
  def default
    render(CampaignProgressComponent.new(percentage: 45.0, status: "running", eta: 2.hours.from_now))
  end

  def completed
    render(CampaignProgressComponent.new(percentage: 100.0, status: "completed", eta: 10.minutes.ago))
  end

  def pending
    render(CampaignProgressComponent.new(percentage: 0.0, status: "pending", eta: nil))
  end

  def failed
    render(CampaignProgressComponent.new(percentage: 30.0, status: "failed", eta: 3.hours.from_now))
  end

  def paused
    render(CampaignProgressComponent.new(percentage: 60.0, status: "paused", eta: 4.hours.from_now))
  end
end
