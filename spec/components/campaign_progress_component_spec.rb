# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe CampaignProgressComponent, type: :component do
  include ActionView::Helpers::DateHelper
  include ActiveSupport::Testing::TimeHelpers

  context "with running attack" do
    it "renders progress, status, eta, and aria labels" do
      eta = 2.hours.from_now
      render_inline(described_class.new(percentage: 45.12, status: "running", eta: eta, label: "Progress"))

      expect(page).to have_css(".progress-bar[style='width: 45.12%']")
      expect(page).to have_css(".badge.text-bg-primary", text: "Running")
      expect(page).to have_css("i.bi.bi-spinner")
      expect(page).to have_css("[aria-label='Status: Running']")
      expect(page).to have_css("[aria-label='Estimated time of arrival']")
    end
  end

  context "with completed attack" do
    it "renders completion status and eta text" do
      render_inline(described_class.new(percentage: 100.0, status: "completed", eta: 1.hour.ago))

      expect(page).to have_css(".badge.text-bg-success", text: "Completed")
      expect(page).to have_css("small", text: "100.00%")
      expect(page).to have_text("Completed")
    end
  end

  context "with no eta" do
    it "renders N/A for eta when status is pending" do
      render_inline(described_class.new(percentage: 10.0, status: "pending", eta: nil))

      expect(page).to have_text("N/A")
    end

    it "renders Completed for completed status with no eta" do
      render_inline(described_class.new(percentage: 100.0, status: "completed", eta: nil))

      expect(page).to have_text("Completed")
      expect(page).to have_no_text("N/A")
    end

    it "renders Failed for failed status with no eta" do
      render_inline(described_class.new(percentage: 30.0, status: "failed", eta: nil))

      expect(page).to have_text("Failed")
      expect(page).to have_no_text("N/A")
    end

    it "renders Exhausted for exhausted status with no eta" do
      render_inline(described_class.new(percentage: 100.0, status: "exhausted", eta: nil))

      expect(page).to have_text("Exhausted")
      expect(page).to have_no_text("N/A")
    end
  end

  context "with paused attack" do
    it "renders paused badge and icon" do
      render_inline(described_class.new(percentage: 60.0, status: "paused", eta: 3.hours.from_now))

      expect(page).to have_css(".badge.text-bg-warning", text: "Paused")
      expect(page).to have_css("i.bi.bi-pause-circle")
    end
  end

  context "with failed attack" do
    it "renders failed badge and icon" do
      render_inline(described_class.new(percentage: 30.0, status: "failed", eta: 1.hour.from_now))

      expect(page).to have_css(".badge.text-bg-danger", text: "Failed")
      expect(page).to have_css("i.bi.bi-times-circle")
    end
  end

  describe "#formatted_eta" do
    it "formats minutes" do
      travel_to(Time.zone.parse("2024-01-01 10:00:00")) do
        component = described_class.new(percentage: 10.0, status: "running", eta: 10.minutes.from_now)

        expect(component.formatted_eta).to eq("ETA: ~#{distance_of_time_in_words(Time.current, 10.minutes.from_now)}")
      end
    end

    it "formats hours" do
      travel_to(Time.zone.parse("2024-01-01 10:00:00")) do
        component = described_class.new(percentage: 10.0, status: "running", eta: 2.hours.from_now)

        expect(component.formatted_eta).to eq("ETA: ~#{distance_of_time_in_words(Time.current, 2.hours.from_now)}")
      end
    end

    it "formats days" do
      travel_to(Time.zone.parse("2024-01-01 10:00:00")) do
        component = described_class.new(percentage: 10.0, status: "running", eta: 2.days.from_now)

        expect(component.formatted_eta).to eq("ETA: ~#{distance_of_time_in_words(Time.current, 2.days.from_now)}")
      end
    end
  end

  describe "#formatted_percentage" do
    it "formats zero" do
      component = described_class.new(percentage: 0.0, status: "pending", eta: nil)

      expect(component.formatted_percentage).to eq("0.00%")
    end

    it "formats full completion" do
      component = described_class.new(percentage: 100.0, status: "completed", eta: nil)

      expect(component.formatted_percentage).to eq("100.00%")
    end

    it "formats decimals" do
      component = described_class.new(percentage: 12.3456, status: "running", eta: nil)

      expect(component.formatted_percentage).to eq("12.35%")
    end
  end
end
