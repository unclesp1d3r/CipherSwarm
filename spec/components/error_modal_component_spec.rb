# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe ErrorModalComponent, type: :component do
  include Rails.application.routes.url_helpers
  context "with info severity error" do
    it "renders modal content" do
      timestamp = Time.zone.parse("2024-01-01 10:00:00")
      error = build_stubbed(:agent_error, severity: :info, created_at: timestamp, message: "Info error")
      render_inline(described_class.new(error: error, modal_id: "error-1"))

      expect(page).to have_css("#error-1")
      expect(page).to have_css(".badge.text-bg-info", text: "Info")
      expect(page).to have_text("Info error")
      expect(page).to have_text(timestamp.strftime("%b %d, %Y %I:%M %p"))
    end
  end

  context "with critical severity error" do
    it "renders critical icon and badge" do
      error = build_stubbed(:agent_error, severity: :critical)
      render_inline(described_class.new(error: error, modal_id: "error-2"))

      expect(page).to have_css(".badge.text-bg-danger", text: "Critical")
      expect(page).to have_css("i.bi.bi-x-octagon")
    end
  end

  context "with task association" do
    it "renders task link to attack when task exists" do
      campaign = create(:campaign)
      attack = create(:attack, campaign: campaign)
      task = create(:task, attack: attack)
      error = build_stubbed(:agent_error, severity: :warning, task_id: task.id)
      render_inline(described_class.new(error: error, modal_id: "error-3"))

      expect(page).to have_link("View Task ##{task.id}", href: campaign_attack_path(campaign, attack))
    end

    it "renders plain text when task does not exist" do
      error = build_stubbed(:agent_error, severity: :warning, task_id: 9999)
      render_inline(described_class.new(error: error, modal_id: "error-3b"))

      expect(page).to have_text("Task #9999")
      expect(page).to have_no_link("View Task #9999")
    end
  end

  context "with metadata" do
    it "renders metadata JSON" do
      error = build_stubbed(:agent_error, severity: :warning, metadata: { "code" => "E42" })
      render_inline(described_class.new(error: error, modal_id: "error-4"))

      expect(page).to have_css("pre.code", text: JSON.pretty_generate(error.metadata))
    end
  end

  context "without task" do
    it "does not render task link" do
      error = build_stubbed(:agent_error, severity: :warning, task_id: nil)
      render_inline(described_class.new(error: error, modal_id: "error-5"))

      expect(page).to have_no_link("View Task")
    end
  end

  context "with severity variants" do
    it "renders info badge" do
      error = build_stubbed(:agent_error, severity: :info)
      render_inline(described_class.new(error: error, modal_id: "error-info"))

      expect(page).to have_css(".badge.text-bg-info", text: "Info")
    end

    it "renders warning badge" do
      error = build_stubbed(:agent_error, severity: :warning)
      render_inline(described_class.new(error: error, modal_id: "error-warning"))

      expect(page).to have_css(".badge.text-bg-warning", text: "Warning")
    end

    it "renders minor badge" do
      error = build_stubbed(:agent_error, severity: :minor)
      render_inline(described_class.new(error: error, modal_id: "error-minor"))

      expect(page).to have_css(".badge.text-bg-warning", text: "Minor")
    end

    it "renders major badge" do
      error = build_stubbed(:agent_error, severity: :major)
      render_inline(described_class.new(error: error, modal_id: "error-major"))

      expect(page).to have_css(".badge.text-bg-danger", text: "Major")
    end

    it "renders critical badge" do
      error = build_stubbed(:agent_error, severity: :critical)
      render_inline(described_class.new(error: error, modal_id: "error-critical"))

      expect(page).to have_css(".badge.text-bg-danger", text: "Critical")
    end

    it "renders fatal badge" do
      error = build_stubbed(:agent_error, severity: :fatal)
      render_inline(described_class.new(error: error, modal_id: "error-fatal"))

      expect(page).to have_css(".badge.text-bg-dark", text: "Fatal")
    end
  end

  context "with modal size" do
    it "applies size class" do
      error = build_stubbed(:agent_error, severity: :info)
      render_inline(described_class.new(error: error, modal_id: "error-6", size: "sm"))

      expect(page).to have_css(".modal-dialog.modal-sm")
    end
  end

  context "with accessibility attributes" do
    it "sets aria attributes and tabindex" do
      error = build_stubbed(:agent_error, severity: :info)
      render_inline(described_class.new(error: error, modal_id: "error-7"))

      expect(page).to have_css("#error-7[tabindex='-1']")
      expect(page).to have_css("#error-7[aria-hidden='true']")
      expect(page).to have_css("#error-7[aria-labelledby='error-7-title']")
    end
  end

  context "with close button" do
    it "renders data-bs-dismiss attribute" do
      error = build_stubbed(:agent_error, severity: :info)
      render_inline(described_class.new(error: error, modal_id: "error-8"))

      expect(page).to have_css("button[data-bs-dismiss='modal']")
    end
  end
end
