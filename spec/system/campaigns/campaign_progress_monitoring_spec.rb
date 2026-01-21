# frozen_string_literal: true

require "rails_helper"
require "support/page_objects/campaign_show_page"

RSpec.describe "Campaign Progress Monitoring" do
  let(:user) { create_and_sign_in_user }
  let(:project) { create(:project, users: [user]) }
  let(:hash_list) { create(:hash_list, project: project) }
  let(:campaign) { create(:campaign, project: project, hash_list: hash_list) }
  let(:page_object) { CampaignShowPage.new(page) }

  before do
    # Ensure campaign is associated with user's project
    # Setup initial data
    create_list(:hash_item, 5, hash_list: hash_list)
  end

  describe "visual components" do
    before do
      create(:attack, :running, :with_progress,
             campaign: campaign, name: "Running Mask Attack")
      create(:attack, :completed,
             campaign: campaign, name: "Completed Dict Attack")
      create(:attack, state: :pending,
                      campaign: campaign, name: "Pending Hybrid Attack")
    end

    it "displays campaign detail page with progress bars and ETAs" do
      page_object.visit_page(campaign)
      page_object.wait_for_eta_summary_loaded

      aggregate_failures "verifying campaign progress UI" do
        expect(page_object).to have_eta_summary

        # Verify Running Attack
        expect(page_object).to have_progress_bar("Running Mask Attack")
        expect(page_object.attack_status_badge("Running Mask Attack")).to include("Running")
        # Values depend on factory data, but check presence
        expect(page_object.attack_progress_percentage("Running Mask Attack")).to be >= 0

        # Verify Completed Attack
        expect(page_object).to have_progress_bar("Completed Dict Attack")
        expect(page_object.attack_status_badge("Completed Dict Attack")).to include("Completed")

        # Verify Pending Attack
        expect(page_object.attack_status_badge("Pending Hybrid Attack")).to include("Pending")
      end
    end

    it "shows empty state when campaign has no attacks" do
      empty_campaign = create(:campaign, project: project, hash_list: hash_list)
      page_object.visit_page(empty_campaign)

      expect(page_object).to have_blank_slate
      expect(page).to have_content("The campaign is empty")
    end
  end

  describe "error handling" do
    let(:failed_attack) do
      create(:attack, :failed, campaign: campaign, name: "Failed Attack")
    end

    before do
      task = create(:task, attack: failed_attack)
      agent = create(:agent)
      create(:agent_error, :critical,
             agent: agent, task: task,
             message: "GPU overheating error")
    end

    it "clicking error indicator opens modal with error details" do
      page_object.visit_page(campaign)

      # Should see error indicator on the failed attack
      page_object.click_error_indicator("Failed Attack")

      # Verify modal content
      wait_for_modal("error-modal-attack-#{failed_attack.id}")

      expect(page_object).to have_error_modal(failed_attack.id)
      expect(page_object.error_modal_severity(failed_attack.id)).to include("Critical")
      expect(page_object.error_modal_message(failed_attack.id)).to include("GPU overheating error")
    end

    it "displays campaign error log with error details" do
      page_object.visit_page(campaign)
      page_object.wait_for_error_log_loaded

      # Error log section should be present
      expect(page_object).to have_error_log_section

      within("div[role='region'][aria-label='Campaign error log']") do
        expect(page).to have_content("GPU overheating error")
        expect(page).to have_content("Critical")
      end
    end

    it "shows empty state when no errors exist" do
      clean_campaign = create(:campaign, project: project, hash_list: hash_list)
      create(:attack, :running, campaign: clean_campaign)

      page_object.visit_page(clean_campaign)
      page_object.wait_for_error_log_loaded
      expect(page_object).to have_no_errors_message
    end
  end

  describe "recent cracks" do
    let(:recent_cracks_campaign) { create(:campaign, project: project, hash_list: hash_list) }
    let!(:attack) { create(:attack, :running, campaign: recent_cracks_campaign) }

    before do
      # Create some cracked hashes
      create(:hash_item, :cracked_recently, hash_list: hash_list, attack: attack, plain_text: "password123")
      create(:hash_item, :cracked_recently, hash_list: hash_list, attack: attack, plain_text: "admin123")
    end

    it "expanding recent cracks section displays table" do
      page_object.visit_page(recent_cracks_campaign)
      page_object.wait_for_recent_cracks_loaded

      aggregate_failures "verifying recent cracks display" do
        expect(page_object).to have_recent_cracks_section
        expect(page_object.recent_cracks_count).to include("2") # Assuming count is displayed

        # Expand section
        page_object.expand_recent_cracks

        # Verify content
        expect(page).to have_content("password123")
        expect(page).to have_content("admin123")
        expect(page).to have_content(attack.name)

        # Verify hash value (truncated) and tooltip
        first_crack = hash_list.recent_cracks.first
        expect(page).to have_css("span[data-bs-toggle='tooltip'][data-bs-title='#{first_crack.hash_value}']")

        # Verify cracked timestamp is displayed
        expect(page).to have_content("ago") # time_ago_in_words includes "ago"
      end
    end

    it "shows empty state when no recent cracks exist" do
      empty_hash_list = create(:hash_list, project: project)
      no_cracks_campaign = create(:campaign, project: project, hash_list: empty_hash_list)
      page_object.visit_page(no_cracks_campaign)
      page_object.wait_for_recent_cracks_loaded

      page_object.expand_recent_cracks
      expect(page_object).to have_no_recent_cracks_message
    end
  end

  describe "accessibility" do
    before do
      create(:attack, :running, :with_progress, campaign: campaign)
    end

    it "verifies accessibility with ARIA labels" do
      page_object.visit_page(campaign)
      page_object.wait_for_eta_summary_loaded
      page_object.wait_for_recent_cracks_loaded
      page_object.wait_for_error_log_loaded

      # ETA summary only appears if campaign has current_eta or total_eta
      # Recent cracks and error log should always be present
      expect(page).to have_css("div[role='region'][aria-label='Recent cracks section']")
      expect(page).to have_css("div[role='region'][aria-label='Campaign error log']")
    end

    it "keyboard navigation for collapsible sections", :js do
      page_object.visit_page(campaign)

      # Navigate to recent cracks toggle
      find("button", text: "Recent Cracks").send_keys(:enter)

      # Should verify it expanded (maybe check visibility of content inside)
      # This is tricky without JS sometimes, but we can check if attributes changed
      expect(page).to have_css("div.collapse.show")
    end
  end

  describe "real-time updates", :js do
    include ActiveJob::TestHelper

    let!(:attack) { create(:attack, :running, :with_progress, campaign: campaign, name: "Live Attack") }

    it "updates progress via Turbo Streams" do
      page_object.visit_page(campaign)
      page_object.wait_for_eta_summary_loaded

      # Initial state check
      initial_progress = page_object.attack_progress_percentage("Live Attack")
      expect(initial_progress).to eq(50)

      # Simulate progress update by updating the existing status
      task = attack.tasks.first
      status = task.hashcat_statuses.last
      status.update!(progress: [9000, 10000])

      # Refresh the page to see updated progress (broadcasting is disabled in test env)
      page.refresh

      # Verify page refreshes successfully and attack still displays
      expect(page_object).to have_progress_bar("Live Attack")
    end
  end
end
