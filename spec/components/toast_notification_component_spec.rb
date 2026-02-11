# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe ToastNotificationComponent, type: :component do
  describe "rendering" do
    it "renders the toast with the message" do
      render_inline(described_class.new(message: "Task completed"))
      expect(page).to have_text("Task completed")
    end

    it "renders the toast data-controller attribute" do
      render_inline(described_class.new(message: "Test"))
      expect(page).to have_css("[data-controller='toast']")
    end

    it "renders autohide and delay values" do
      render_inline(described_class.new(message: "Test"))
      expect(page).to have_css("[data-toast-autohide-value='true']")
      expect(page).to have_css("[data-toast-delay-value='5000']")
    end

    it "renders close button" do
      render_inline(described_class.new(message: "Test"))
      expect(page).to have_css("button[data-bs-dismiss='toast']")
    end
  end

  describe "variants" do
    it "renders success variant by default" do
      render_inline(described_class.new(message: "Done"))
      expect(page).to have_css(".toast.border-success")
      expect(page).to have_css("i.bi.bi-check-circle-fill.text-success")
    end

    it "renders danger variant" do
      render_inline(described_class.new(message: "Error", variant: "danger"))
      expect(page).to have_css(".toast.border-danger")
      expect(page).to have_css("i.bi.bi-exclamation-triangle-fill.text-danger")
    end

    it "renders warning variant" do
      render_inline(described_class.new(message: "Caution", variant: "warning"))
      expect(page).to have_css(".toast.border-warning")
      expect(page).to have_css("i.bi.bi-exclamation-triangle-fill.text-warning")
    end

    it "renders info variant" do
      render_inline(described_class.new(message: "FYI", variant: "info"))
      expect(page).to have_css(".toast.border-info")
      expect(page).to have_css("i.bi.bi-info-circle-fill.text-info")
    end
  end

  describe "#icon_name" do
    it "returns check-circle-fill for success" do
      component = described_class.new(message: "x", variant: "success")
      expect(component.icon_name).to eq("check-circle-fill")
    end

    it "returns exclamation-triangle-fill for danger" do
      component = described_class.new(message: "x", variant: "danger")
      expect(component.icon_name).to eq("exclamation-triangle-fill")
    end

    it "returns info-circle-fill for unknown variant" do
      component = described_class.new(message: "x", variant: "custom")
      expect(component.icon_name).to eq("info-circle-fill")
    end
  end
end
