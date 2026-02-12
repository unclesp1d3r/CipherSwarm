# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"
require "support/page_objects/campaign_show_page"

RSpec.describe "Campaign progress component regressions" do
  let(:user) { create_and_sign_in_user }
  let(:project) { create(:project, users: [user]) }
  let(:hash_list) { create(:hash_list, project: project) }
  let(:campaign) { create(:campaign, project: project, hash_list: hash_list) }
  let(:page_object) { CampaignShowPage.new(page) }

  before do
    create_list(:hash_item, 3, hash_list: hash_list)
  end

  describe "correct Bootstrap icons for status badges" do
    before do
      create(:attack, :running, :with_progress, campaign: campaign, name: "Running Attack")
      create(:attack, :completed, campaign: campaign, name: "Completed Attack")
      create(:attack, :failed, campaign: campaign, name: "Failed Attack")
      create(:attack, state: :paused, campaign: campaign, name: "Paused Attack")
      create(:attack, state: :pending, campaign: campaign, name: "Pending Attack")
    end

    it "renders valid Bootstrap icons for each attack state", :aggregate_failures, skip: ENV["CI"].present? do
      page_object.visit_page(campaign)
      page_object.wait_for_eta_summary_loaded

      # Running attack uses arrow-repeat icon
      running_item = find(".stepper-item", text: "Running Attack")
      expect(running_item).to have_css("i.bi.bi-arrow-repeat")

      # Completed attack uses check-circle icon
      completed_item = find(".stepper-item", text: "Completed Attack")
      expect(completed_item).to have_css("i.bi.bi-check-circle")

      # Failed attack uses x-circle icon
      failed_item = find(".stepper-item", text: "Failed Attack")
      expect(failed_item).to have_css("i.bi.bi-x-circle")

      # Paused attack uses pause-circle-fill icon
      paused_item = find(".stepper-item", text: "Paused Attack")
      expect(paused_item).to have_css("i.bi.bi-pause-circle-fill")

      # Pending attack uses clock icon
      pending_item = find(".stepper-item", text: "Pending Attack")
      expect(pending_item).to have_css("i.bi.bi-clock")
    end
  end

  describe "ETA fallback text for non-terminal states" do
    before do
      create(:attack, state: :pending, campaign: campaign, name: "Pending No ETA")
      create(:attack, :running, campaign: campaign, name: "Running No ETA")
      create(:attack, state: :paused, campaign: campaign, name: "Paused No ETA")
      create(:attack, :completed, campaign: campaign, name: "Completed No ETA")
      create(:attack, :failed, campaign: campaign, name: "Failed No ETA")
    end

    it "shows 'Calculating...' for pending/running/paused and terminal labels for completed/failed",
       :aggregate_failures do
      page_object.visit_page(campaign)
      page_object.wait_for_eta_summary_loaded

      # Non-terminal states without ETA show "Calculating..."
      pending_item = find(".stepper-item", text: "Pending No ETA")
      expect(pending_item).to have_text("Calculating\u2026")

      running_item = find(".stepper-item", text: "Running No ETA")
      expect(running_item).to have_text("Calculating\u2026")

      paused_item = find(".stepper-item", text: "Paused No ETA")
      expect(paused_item).to have_text("Calculating\u2026")

      # Terminal states show their status label
      completed_item = find(".stepper-item", text: "Completed No ETA")
      expect(completed_item).to have_text("Completed")
      expect(completed_item).to have_no_text("Calculating")

      failed_item = find(".stepper-item", text: "Failed No ETA")
      expect(failed_item).to have_text("Failed")
      expect(failed_item).to have_no_text("Calculating")
    end
  end
end
