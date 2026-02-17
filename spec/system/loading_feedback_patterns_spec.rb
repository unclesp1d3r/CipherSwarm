# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Loading & Feedback Patterns", skip: ENV["CI"].present? do
  let(:user) { create_and_sign_in_user }
  let(:project) { create(:project) }

  before do
    user.projects << project unless user.projects.include?(project)
  end

  describe "skeleton loaders on agent list" do
    it "renders turbo frame container for agent cards" do
      create(:agent, user: user, projects: [project])

      visit agents_path

      # Turbo frame wraps the agent cards content
      expect(page).to have_css("turbo-frame#agents-cards")
    end

    it "loads actual agent cards after skeleton phase" do
      agent = create(:agent, user: user, projects: [project], state: :active)

      visit agents_path

      # Wait for cards to load (replacing any skeleton placeholders)
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(agent)}", wait: 5)
      expect(page).to have_no_css(".placeholder-glow")
    end
  end

  describe "toast notifications on task actions" do
    let(:agent) { create(:agent, projects: [project]) }
    let(:campaign) { create(:campaign, project: project) }
    let(:attack) { create(:dictionary_attack, campaign: campaign) }

    def sign_in_project_user
      page.driver.browser.manage.delete_all_cookies
      new_user = create_and_sign_in_user
      create(:project_user, user: new_user, project: project)
      Rails.cache.clear
      new_user
    end

    it "task cancel action updates state via Turbo Stream" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)
      expect(page).to have_button("Cancel")

      accept_confirm("Are you sure you want to cancel this task?") do
        click_button "Cancel"
      end

      # Turbo Stream updates don't trigger flash - verify DB directly
      sleep 1
      task.reload
      expect(task.state).to eq("failed")
    end

    it "task retry action updates state via Turbo Stream" do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "failed", last_error: "GPU error") # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)
      click_button "Retry"

      sleep 1
      task.reload
      expect(task.state).to eq("pending")
    end
  end

  describe "system health page loading" do
    before do
      Sidekiq.redis { |conn| conn.del(SystemHealthCheckService::LOCK_KEY) }
    end

    it "displays service cards on system health page" do
      visit system_health_path

      expect(page).to have_content("System Health")
      expect(page).to have_css(".card", minimum: 4)
    end

    it "shows refresh button for reloading health data" do
      visit system_health_path

      expect(page).to have_link("Refresh")
    end
  end

  describe "campaign page loading patterns" do
    let(:hash_list) { create(:hash_list, project: project) }
    let(:campaign) { create(:campaign, project: project, hash_list: hash_list) }

    it "loads campaign show page with ARIA regions" do
      create(:attack, :running, :with_progress, campaign: campaign)

      visit campaign_path(campaign)

      # Turbo frames should eventually load
      expect(page).to have_css("div[role='region'][aria-label='Recent cracks section']", wait: 5)
      expect(page).to have_css("div[role='region'][aria-label='Campaign error log']", wait: 5)
    end
  end

  describe "empty states" do
    it "shows no agents message when user has none" do
      # Fresh user with no agents
      visit agents_path

      expect(page).to have_content("Create your first agent to start cracking hashes")
      expect(page).to have_link("New Agent")
    end
  end
end
