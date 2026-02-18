# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"
require "support/page_objects/campaign_show_page"

RSpec.describe "Campaign Progress Monitoring (Integration)", skip: ENV["CI"].present? do
  let(:user) { create_and_sign_in_user }
  let(:project) { create(:project, users: [user]) }
  let(:hash_list) { create(:hash_list, project: project) }
  let(:campaign) { create(:campaign, project: project, hash_list: hash_list) }
  let(:page_object) { CampaignShowPage.new(page) }

  before do
    create_list(:hash_item, 5, hash_list: hash_list)
  end

  describe "campaign detail page with attack stepper" do
    before do
      create(:attack, :running, :with_progress,
             campaign: campaign, name: "Active Mask Attack")
      create(:attack, :completed,
             campaign: campaign, name: "Done Dictionary Attack")
      create(:attack, state: :pending,
                      campaign: campaign, name: "Queued Hybrid Attack")
    end

    it "displays attack stepper with progress bars and ETAs", :aggregate_failures do
      page_object.visit_page(campaign)
      page_object.wait_for_eta_summary_loaded

      expect(page_object).to have_progress_bar("Active Mask Attack")
      expect(page_object.attack_status_badge("Active Mask Attack")).to include("Running")
      expect(page_object.attack_progress_percentage("Active Mask Attack")).to be >= 0

      expect(page_object).to have_progress_bar("Done Dictionary Attack")
      expect(page_object.attack_status_badge("Done Dictionary Attack")).to include("Completed")

      expect(page_object.attack_status_badge("Queued Hybrid Attack")).to include("Pending")
    end
  end

  describe "error indicator and modal" do
    let(:failed_attack) do
      create(:attack, :failed, campaign: campaign, name: "Crashed Attack")
    end

    before do
      task = create(:task, attack: failed_attack)
      create(:agent_error, :critical,
             agent: task.agent, task: task,
             message: "CUDA driver crash")
    end

    it "opens error modal when clicking error indicator", :aggregate_failures do
      page_object.visit_page(campaign)

      page_object.click_error_indicator("Crashed Attack")
      wait_for_modal("error-modal-attack-#{failed_attack.id}")

      expect(page_object).to have_error_modal(failed_attack.id)
      expect(page_object.error_modal_severity(failed_attack.id)).to include("Critical")
      expect(page_object.error_modal_message(failed_attack.id)).to include("CUDA driver crash")
    end
  end

  describe "recent cracks section" do
    let(:cracking_campaign) { create(:campaign, project: project, hash_list: hash_list) }
    let!(:attack) { create(:attack, :running, campaign: cracking_campaign) }

    before do
      create(:hash_item, :cracked_recently, hash_list: hash_list, attack: attack, plain_text: "letmein")
      create(:hash_item, :cracked_recently, hash_list: hash_list, attack: attack, plain_text: "qwerty")
    end

    it "displays cracked hashes in expandable section", :aggregate_failures do
      page_object.visit_page(cracking_campaign)
      page_object.wait_for_recent_cracks_loaded

      expect(page_object).to have_recent_cracks_section
      page_object.expand_recent_cracks

      expect(page).to have_content("letmein")
      expect(page).to have_content("qwerty")
    end
  end

  describe "real-time progress updates" do
    include ActiveJob::TestHelper

    let!(:attack) { create(:attack, :running, :with_progress, campaign: campaign, name: "Streaming Attack") }

    it "shows updated progress after page refresh", :aggregate_failures do
      page_object.visit_page(campaign)
      page_object.wait_for_eta_summary_loaded

      expect(page_object).to have_progress_bar("Streaming Attack")

      # Simulate progress update
      task = attack.tasks.first
      status = task.hashcat_statuses.last
      status.update!(progress: [8500, 10000])

      page.refresh

      expect(page_object).to have_progress_bar("Streaming Attack")
    end
  end

  describe "Turbo Stream broadcasts don't disrupt user interaction" do
    before do
      create(:attack, :running, :with_progress, campaign: campaign, name: "Broadcast Attack")
    end

    it "maintains page structure after model update and refresh" do
      page_object.visit_page(campaign)
      page_object.wait_for_eta_summary_loaded
      page_object.wait_for_recent_cracks_loaded
      page_object.wait_for_error_log_loaded

      expect(page).to have_css("div[role='region'][aria-label='Recent cracks section']")
      expect(page).to have_css("div[role='region'][aria-label='Campaign error log']")
    end
  end
end
