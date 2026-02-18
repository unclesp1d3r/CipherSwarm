# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"
require "support/page_objects/campaign_show_page"

RSpec.describe "Error Investigation", skip: ENV["CI"].present? do
  let(:user) { create_and_sign_in_user }
  let(:project) { create(:project, users: [user]) }
  let(:hash_list) { create(:hash_list, project: project) }
  let(:campaign) { create(:campaign, project: project, hash_list: hash_list) }
  let(:page_object) { CampaignShowPage.new(page) }

  describe "error modal from campaign page" do
    let(:failed_attack) do
      create(:attack, :failed, campaign: campaign, name: "Error Attack")
    end

    before do
      task = create(:task, attack: failed_attack)
      create(:agent_error, :critical,
             agent: task.agent, task: task,
             message: "Segmentation fault in kernel")
    end

    it "opens error modal with error details", :aggregate_failures do
      page_object.visit_page(campaign)

      page_object.click_error_indicator("Error Attack")
      wait_for_modal("error-modal-attack-#{failed_attack.id}")

      expect(page_object).to have_error_modal(failed_attack.id)
      expect(page_object.error_modal_severity(failed_attack.id)).to include("Critical")
      expect(page_object.error_modal_message(failed_attack.id)).to include("Segmentation fault in kernel")
    end
  end

  describe "campaign error log display" do
    let(:failed_attack) do
      create(:attack, :failed, campaign: campaign, name: "Logged Error Attack")
    end

    before do
      task = create(:task, attack: failed_attack)
      agent = task.agent
      create(:agent_error, :critical, agent: agent, task: task, message: "Hardware failure detected")
      create(:agent_error, agent: agent, task: task, severity: :warning, message: "Temperature warning")
    end

    it "displays error log section with error details", :aggregate_failures do
      page_object.visit_page(campaign)
      page_object.wait_for_error_log_loaded

      expect(page_object).to have_error_log_section

      within("div[role='region'][aria-label='Campaign error log']") do
        expect(page).to have_content("Hardware failure detected")
        expect(page).to have_content("Critical")
        expect(page).to have_content("Temperature warning")
      end
    end
  end

  describe "error severity badges" do
    let(:failed_attack) do
      create(:attack, :failed, campaign: campaign, name: "Multi-Severity Attack")
    end

    before do
      task = create(:task, attack: failed_attack)
      agent = task.agent
      create(:agent_error, agent: agent, task: task, severity: :critical, message: "Critical error")
      create(:agent_error, agent: agent, task: task, severity: :warning, message: "Warning error")
      create(:agent_error, agent: agent, task: task, severity: :info, message: "Info message")
    end

    it "displays severity badges for each error level", :aggregate_failures do
      page_object.visit_page(campaign)
      page_object.wait_for_error_log_loaded

      within("div[role='region'][aria-label='Campaign error log']") do
        expect(page).to have_content("Critical")
        expect(page).to have_content("Warning")
        expect(page).to have_content("Info")
      end
    end
  end

  describe "no errors state" do
    it "shows empty state when campaign has no errors" do
      create(:attack, :running, campaign: campaign)

      page_object.visit_page(campaign)
      page_object.wait_for_error_log_loaded

      expect(page_object).to have_no_errors_message
    end
  end

  describe "task error display" do
    it "shows last error on task detail page" do
      task = create(:task, attack: create(:dictionary_attack, campaign: campaign), agent: create(:agent, projects: [project]))
      task.update_columns(state: "failed", last_error: "Out of memory") # rubocop:disable Rails/SkipsModelValidations

      visit task_path(task)

      expect(page).to have_content("Last Error")
      expect(page).to have_content("Out of memory")
    end
  end
end
