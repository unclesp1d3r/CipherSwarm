# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Task Detail Investigation", skip: ENV["CI"].present? do
  let(:project) { create(:project) }
  let(:agent) { create(:agent, projects: [project]) }
  let(:campaign) { create(:campaign, project: project) }
  let(:attack) { create(:dictionary_attack, campaign: campaign) }

  def sign_in_project_user
    user = create_and_sign_in_user
    create(:project_user, user: user, project: project)
    Rails.cache.clear
    user
  end

  describe "task detail page content" do
    it "displays full task information", :aggregate_failures do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      # Task header and breadcrumb
      expect(page).to have_content("Task ##{task.id}")
      expect(page).to have_link(campaign.name)
      expect(page).to have_link(attack.name)

      # Task details
      expect(page).to have_content("Task Details")
      expect(page).to have_link(agent.host_name)

      # Progress section
      expect(page).to have_content("Progress")
      expect(page).to have_content("Percentage")
      expect(page).to have_content("ETA")

      # Timestamps section
      expect(page).to have_content("Timestamps")
      expect(page).to have_content("Created")
    end

    it "displays error section when last_error is present" do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "failed", last_error: "GPU memory exhausted") # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_content("Last Error")
      expect(page).to have_content("GPU memory exhausted")
    end

    it "displays recent status history when statuses exist" do
      task = create(:task, attack: attack, agent: agent)
      create(:hashcat_status, task: task)
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_content("Recent Status History")
      expect(page).to have_table
      expect(page).to have_content("Time")
      expect(page).to have_content("Speed")
      expect(page).to have_content("Recovered")
    end

    it "shows empty state when no status history exists" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_content("No status history available")
    end
  end

  describe "cancel action" do
    it "cancels a pending task via button click", :aggregate_failures do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)
      expect(page).to have_button("Cancel")

      accept_confirm("Are you sure you want to cancel this task?") do
        click_button "Cancel"
      end

      sleep 1
      task.reload
      expect(task.state).to eq("failed")
    end

    it "reflects cancelled state after page reload" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)
      accept_confirm("Are you sure you want to cancel this task?") do
        click_button "Cancel"
      end

      sleep 1
      visit task_path(task)
      expect(page).to have_content("Task ##{task.id}")
      expect(page).to have_no_button("Cancel")
    end
  end

  describe "retry action" do
    it "retries a failed task and transitions to pending", :aggregate_failures do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "failed", last_error: "GPU error", retry_count: 0) # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)
      expect(page).to have_button("Retry")
      click_button "Retry"

      sleep 1
      task.reload
      expect(task.state).to eq("pending")
      expect(task.retry_count).to eq(1)
      expect(task.last_error).to be_nil
    end

    it "reflects retried state after page reload" do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "failed", last_error: "GPU error") # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)
      click_button "Retry"

      sleep 1
      visit task_path(task)
      expect(page).to have_content("Task ##{task.id}")
      expect(page).to have_no_button("Retry")
    end
  end

  describe "reassign action" do
    it "reassigns task to a compatible agent", :aggregate_failures do
      other_agent = create(:agent, projects: [project])
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      select other_agent.host_name, from: "agent_id"
      click_button "Reassign"

      sleep 1
      task.reload
      expect(task.agent_id).to eq(other_agent.id)
    end

    it "shows no compatible agents message when none available" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_content("No compatible agents available")
    end

    it "does not show reassign for completed tasks" do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "completed") # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)
      expect(page).to have_content("Task ##{task.id}")

      expect(page).to have_no_button("Reassign")
      expect(page).to have_no_select("agent_id")
    end
  end

  describe "download results" do
    it "displays download results link with correct path for completed tasks" do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "completed") # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)

      download_link = find_link("Download Results")
      expect(download_link[:href]).to include(download_results_task_path(task))
    end
  end

  describe "logs navigation" do
    it "navigates to logs page and back", :aggregate_failures do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)
      click_link "Logs"

      expect(page).to have_content("Status Logs")
      expect(page).to have_link("Back to Task")

      click_link "Back to Task"
      expect(page).to have_current_path(task_path(task))
    end
  end

  describe "authorization" do
    it "denies access to users not in the project" do
      task = create(:task, attack: attack, agent: agent)
      create_and_sign_in_user

      visit task_path(task)

      expect(page).to have_css("body")
      expect(page).to have_no_content("Task ##{task.id}")
    end

    it "allows admin users to access any task" do
      task = create(:task, attack: attack, agent: agent)
      create_and_sign_in_admin

      visit task_path(task)

      expect(page).to have_content("Task ##{task.id}")
      expect(page).to have_content("Task Details")
    end
  end
end
