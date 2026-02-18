# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe SystemHealthCardComponent, type: :component do
  describe "healthy service" do
    before do
      render_inline(described_class.new(service_name: "PostgreSQL", status: :healthy, latency: 1.23))
    end

    it "renders service name" do
      expect(page).to have_text("PostgreSQL")
    end

    it "renders healthy badge" do
      expect(page).to have_css(".badge.text-bg-success", text: "Healthy")
    end

    it "renders check-circle-fill icon" do
      expect(page).to have_css("i.bi.bi-check-circle-fill.text-success")
    end

    it "renders latency" do
      expect(page).to have_text("1.23 ms")
    end

    it "does not render error message" do
      expect(page).to have_no_css(".text-danger")
    end
  end

  describe "unhealthy service" do
    before do
      render_inline(described_class.new(
        service_name: "Redis",
        status: :unhealthy,
        error: "Connection refused"
      ))
    end

    it "renders danger badge" do
      expect(page).to have_css(".badge.text-bg-danger", text: "Unhealthy")
    end

    it "renders x-circle-fill icon" do
      expect(page).to have_css("i.bi.bi-x-circle-fill.text-danger")
    end

    it "renders error message" do
      expect(page).to have_css(".text-danger", text: "Connection refused")
    end
  end

  describe "checking service" do
    before do
      render_inline(described_class.new(service_name: "MinIO", status: :checking))
    end

    it "renders warning badge" do
      expect(page).to have_css(".badge.text-bg-warning", text: "Checking")
    end

    it "renders arrow-repeat icon" do
      expect(page).to have_css("i.bi.bi-arrow-repeat.text-warning")
    end
  end

  describe "without latency" do
    it "does not render latency text" do
      render_inline(described_class.new(service_name: "Sidekiq", status: :healthy))
      expect(page).to have_no_text("ms")
    end
  end

  describe "#format_bytes" do
    let(:component) { described_class.new(service_name: "Test", status: :healthy) }

    it "returns nil for nil input" do
      expect(component.format_bytes(nil)).to be_nil
    end

    it "formats bytes" do
      expect(component.format_bytes(500)).to eq("500 Bytes")
    end

    it "formats kilobytes" do
      expect(component.format_bytes(2048)).to eq("2 KB")
    end

    it "formats megabytes" do
      expect(component.format_bytes(5_242_880)).to eq("5 MB")
    end

    it "formats gigabytes" do
      expect(component.format_bytes(2_147_483_648)).to eq("2 GB")
    end
  end

  describe "helper methods" do
    it "returns correct status_variant for healthy" do
      component = described_class.new(service_name: "Test", status: :healthy)
      expect(component.status_variant).to eq("success")
    end

    it "returns correct status_variant for unhealthy" do
      component = described_class.new(service_name: "Test", status: :unhealthy)
      expect(component.status_variant).to eq("danger")
    end

    it "returns secondary status_variant for unknown status" do
      component = described_class.new(service_name: "Test", status: :unknown)
      expect(component.status_variant).to eq("secondary")
    end

    it "returns question-circle icon for unknown status" do
      component = described_class.new(service_name: "Test", status: :unknown)
      expect(component.status_icon_name).to eq("question-circle")
    end

    it "returns correct latency_text" do
      component = described_class.new(service_name: "Test", status: :healthy, latency: 5.67)
      expect(component.latency_text).to eq("5.67 ms")
    end

    it "returns nil latency_text when latency is nil" do
      component = described_class.new(service_name: "Test", status: :healthy)
      expect(component.latency_text).to be_nil
    end
  end
end
