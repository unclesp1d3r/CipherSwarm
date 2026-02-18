# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Task Management", skip: ENV["CI"].present? do
  let(:project) { create(:project) }
  let(:agent) { create(:agent, projects: [project]) }
  let(:campaign) { create(:campaign, project: project) }
  let(:attack) { create(:dictionary_attack, campaign: campaign) }

  # Helper to set up a user with project access and sign them in
  def sign_in_project_user
    user = create_and_sign_in_user
    create(:project_user, user: user, project: project)
    # Clear cached project IDs so ability picks up the new membership
    Rails.cache.clear
    user
  end

  describe "task detail page" do
    it "displays task details and breadcrumb navigation", :aggregate_failures do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      # Breadcrumb navigation
      expect(page).to have_content("Task ##{task.id}")
      expect(page).to have_link(campaign.name)
      expect(page).to have_link(attack.name)

      # Task details card
      expect(page).to have_content("Task Details")
      expect(page).to have_content(task.id.to_s)
      expect(page).to have_link(agent.host_name)
    end

    it "displays progress section" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_content("Progress")
      expect(page).to have_content("Percentage")
      expect(page).to have_content("ETA")
    end

    it "displays timestamps section" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_content("Timestamps")
      expect(page).to have_content("Created")
      expect(page).to have_content("Updated")
      expect(page).to have_content("Start Date")
      expect(page).to have_content("Last Activity")
    end

    it "displays the error section when last_error is present" do
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

  describe "action buttons" do
    it "shows cancel button for pending tasks" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_button("Cancel")
    end

    it "shows retry button for failed tasks" do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "failed") # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_button("Retry")
    end

    it "does not show cancel button for completed tasks" do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "completed") # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_content("Task Details")
      expect(page).to have_no_button("Cancel")
    end

    it "does not show retry button for pending tasks" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_content("Task Details")
      expect(page).to have_no_button("Retry")
    end

    it "always shows logs link" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_link("Logs")
    end

    it "shows download results link for completed tasks" do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "completed") # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_link("Download Results")
    end

    it "shows reassign form with compatible agents" do
      other_agent = create(:agent, projects: [project])
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_select("agent_id")
      expect(page).to have_button("Reassign")
      expect(page).to have_content(other_agent.host_name)
    end

    it "shows no compatible agents message when none available" do
      task = create(:task, attack: attack, agent: agent)
      # No other agents exist for this project
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_content("No compatible agents available")
    end
  end

  describe "cancel action" do
    it "cancels a pending task" do
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

    it "shows updated state after page reload" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      accept_confirm("Are you sure you want to cancel this task?") do
        click_button "Cancel"
      end

      # Turbo Stream updates don't trigger flash - verify DB directly
      sleep 1
      task.reload
      expect(task.state).to eq("failed")

      # Reload page to verify the new state renders correctly
      visit task_path(task)
      expect(page).to have_content("Task Details")
      expect(page).to have_no_button("Cancel")
    end
  end

  describe "retry action" do
    it "retries a failed task" do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "failed", last_error: "GPU error", retry_count: 0) # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_button("Retry")
      click_button "Retry"

      # Turbo Stream updates don't trigger flash - verify DB directly
      sleep 1
      task.reload
      expect(task.state).to eq("pending")
      expect(task.retry_count).to eq(1)
      expect(task.last_error).to be_nil
    end

    it "shows updated state after page reload" do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "failed", last_error: "GPU error") # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)

      click_button "Retry"

      # Turbo Stream updates don't trigger flash - verify DB directly
      sleep 1
      task.reload
      expect(task.state).to eq("pending")

      # Reload page to verify the new state renders correctly
      visit task_path(task)
      expect(page).to have_content("Task Details")
      expect(page).to have_no_button("Retry")
    end
  end

  describe "reassign action" do
    it "reassigns a task to a compatible agent" do
      other_agent = create(:agent, projects: [project])
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)

      select other_agent.host_name, from: "agent_id"
      click_button "Reassign"

      # Turbo Stream updates don't trigger flash - verify DB directly
      sleep 1
      task.reload
      expect(task.agent_id).to eq(other_agent.id)
    end

    it "does not show reassign for completed tasks" do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "completed") # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_content("Task Details")
      expect(page).to have_no_button("Reassign")
      expect(page).to have_no_select("agent_id")
    end

    it "does not show reassign for exhausted tasks" do
      task = create(:task, attack: attack, agent: agent)
      task.update_columns(state: "exhausted") # rubocop:disable Rails/SkipsModelValidations
      sign_in_project_user

      visit task_path(task)

      expect(page).to have_content("Task Details")
      expect(page).to have_no_button("Reassign")
      expect(page).to have_no_select("agent_id")
    end
  end

  describe "logs page" do
    it "navigates to the logs page" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit task_path(task)
      click_link "Logs"

      expect(page).to have_content("Status Logs")
      expect(page).to have_link("Back to Task")
    end

    it "displays status history on the logs page" do
      task = create(:task, attack: attack, agent: agent)
      create(:hashcat_status, task: task)
      sign_in_project_user

      visit logs_task_path(task)

      expect(page).to have_content("Status History")
      expect(page).to have_table
      expect(page).to have_content("Hash Rate")
      expect(page).to have_content("Estimated Stop")
    end

    it "shows empty state when no status history exists" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit logs_task_path(task)

      expect(page).to have_content("No status history available for this task")
    end

    it "displays pagination when more than 50 statuses exist" do
      task = create(:task, attack: attack, agent: agent)
      55.times do |i|
        create(:hashcat_status, task: task, time: i.minutes.ago)
      end
      sign_in_project_user

      visit logs_task_path(task)

      expect(page).to have_css("nav[aria-label='Status history pagination']")
    end

    it "navigates back to task from logs page" do
      task = create(:task, attack: attack, agent: agent)
      sign_in_project_user

      visit logs_task_path(task)
      click_link "Back to Task"

      expect(page).to have_current_path(task_path(task))
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

  describe "authorization" do
    it "denies access to users not in the project" do
      task = create(:task, attack: attack, agent: agent)
      # Sign in user without project membership
      create_and_sign_in_user

      visit task_path(task)

      # CanCanCan redirects unauthorized users - page should have loaded but not show task
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
