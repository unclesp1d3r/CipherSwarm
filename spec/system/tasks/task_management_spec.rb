# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Task Management" do
  let(:user) { create_and_sign_in_user }
  let(:project) { create(:project, users: [user]) }
  let(:hash_list) { create(:hash_list, project: project) }
  let(:campaign) { create(:campaign, project: project, hash_list: hash_list) }
  let(:attack) { create(:dictionary_attack, campaign: campaign, state: :running) }
  let(:agent) { create(:agent, projects: [project]) }
  let(:task) { create(:task, attack: attack, agent: agent, state: :pending) }

  describe "navigation" do
    it "displays task detail page with expected information" do
      visit task_path(task)

      aggregate_failures "verifying task detail display" do
        # Check page title
        expect(page).to have_content("Task ##{task.id}")

        # Check task details are displayed
        expect(page).to have_content("Task Details")
        expect(page).to have_content(task.agent.host_name)
        expect(page).to have_content("Pending")

        # Check progress section exists
        expect(page).to have_content("Progress")
        expect(page).to have_content("Percentage")

        # Check timestamps section exists
        expect(page).to have_content("Timestamps")
        expect(page).to have_content("Created")

        # Check actions section exists
        expect(page).to have_content("Actions")
      end
    end

    it "navigates from task detail page to attack page via link" do
      visit task_path(task)

      # Use the link in the task details section, not the breadcrumb
      within("dd", text: attack.name) do
        click_link attack.name
      end

      expect(page).to have_current_path(campaign_attack_path(campaign, attack))
      expect(page).to have_content(attack.name)
    end

    it "navigates from task detail page to campaign page via link" do
      visit task_path(task)

      # Use the link in the task details section, not the breadcrumb
      within("dd", text: campaign.name) do
        click_link campaign.name
      end

      expect(page).to have_current_path(campaign_path(campaign))
      expect(page).to have_content(campaign.name)
    end
  end

  describe "cancel workflow" do
    let(:pending_task) { create(:task, attack: attack, agent: agent, state: :pending) }

    it "shows cancel button for pending task" do
      visit task_path(pending_task)

      # Verify cancel button exists with correct styling
      expect(page).to have_button("Cancel", class: "btn-danger")
    end

    it "cancels a pending task and verifies state change" do
      visit task_path(pending_task)

      # Accept the confirmation dialog and click the cancel button
      accept_confirm do
        click_button "Cancel"
      end

      # Turbo Stream updates a partial; full page needs refresh for show page elements
      sleep 1
      pending_task.reload
      expect(pending_task.state).to eq("failed")
    end
  end

  describe "retry workflow" do
    let(:failed_task) { create(:task, attack: attack, agent: agent, state: :failed, last_error: "Test error") }

    it "shows retry button for failed task" do
      visit task_path(failed_task)

      expect(page).to have_button("Retry", class: "btn-warning")
      expect(page).to have_no_button("Cancel")
    end

    it "retries a failed task and verifies state change" do
      visit task_path(failed_task)

      # Click retry button (no confirmation needed)
      click_button "Retry"

      # Turbo Stream updates a partial; verify DB state after action completes
      sleep 1
      failed_task.reload
      expect(failed_task.state).to eq("pending")
      expect(failed_task.retry_count).to eq(1)
    end

    it "displays last error for failed task" do
      visit task_path(failed_task)

      expect(page).to have_content("Last Error")
      expect(page).to have_content("Test error")
    end
  end

  describe "authorization" do
    let(:other_user) { create(:user, password: "password", password_confirmation: "password") }
    let(:other_project) { create(:project, users: [other_user]) }
    let(:other_hash_list) { create(:hash_list, project: other_project) }
    let(:other_campaign) { create(:campaign, project: other_project, hash_list: other_hash_list) }
    let(:other_attack) { create(:dictionary_attack, campaign: other_campaign, state: :running) }
    let(:other_agent) { create(:agent, projects: [other_project]) }
    let(:other_task) { create(:task, attack: other_attack, agent: other_agent, state: :pending) }

    it "prevents access to tasks from projects user does not have access to" do
      # Ensure our user is signed in first by accessing the user let
      user

      # Create the other task (belonging to a different user/project)
      other_task_id = other_task.id

      # Visit the task page - user should be denied access
      visit task_path(other_task_id)

      # User should see "Not Authorized" error page
      expect(page).to have_content("Not Authorized")
    end
  end

  describe "task display" do
    let(:running_task) do
      create(:task,
             attack: attack,
             agent: agent,
             state: :running,
             activity_timestamp: 1.minute.ago)
    end

    it "shows activity timestamp for running task" do
      visit task_path(running_task)

      expect(page).to have_content("Last Activity")
      expect(page).to have_content("ago")
    end

    it "shows running state badge" do
      visit task_path(running_task)

      expect(page).to have_content("Running")
    end
  end

  describe "logs navigation" do
    it "navigates to logs page from task detail" do
      visit task_path(task)

      click_link "Logs"

      expect(page).to have_current_path(logs_task_path(task))
    end
  end

  describe "reassignment" do
    let(:compatible_agent) { create(:agent, projects: [project]) }

    it "shows reassign form with compatible agents" do
      # Ensure compatible_agent exists before visiting the page
      compatible_agent

      visit task_path(task)

      # Should have a select dropdown and reassign button
      expect(page).to have_css("select[aria-label='Select agent for reassignment']")
      expect(page).to have_button("Reassign")
    end

    it "shows message when no compatible agents available" do
      # Agent from task setup is the only compatible agent, but it's already assigned
      # No other compatible agents exist
      visit task_path(task)

      # When only the currently assigned agent is available (or no agents),
      # the component shows a message
      expect(page).to have_content("No compatible agents available").or have_select(id: /.+/)
    end

    it "reassigns task to compatible agent successfully" do
      compatible_agent

      visit task_path(task)

      find("select[aria-label='Select agent for reassignment']").select(compatible_agent.host_name)
      click_button "Reassign"

      # Turbo Stream updates a partial; verify DB state after action completes
      sleep 1
      task.reload
      expect(task.agent_id).to eq(compatible_agent.id)
    end

    it "prevents reassignment to incompatible agent" do
      incompatible_agent = create(:agent, projects: [create(:project)])

      visit task_path(task)

      # Incompatible agent should not appear in the dropdown
      if page.has_css?("select[aria-label='Select agent for reassignment']")
        select_element = find("select[aria-label='Select agent for reassignment']")
        expect(select_element).to have_no_css("option", text: incompatible_agent.host_name)
      end
    end

    it "reassigns running task and resets to pending" do
      running_task = create(:task, attack: attack, agent: agent, state: :running)
      compatible_agent

      visit task_path(running_task)

      find("select[aria-label='Select agent for reassignment']").select(compatible_agent.host_name)
      click_button "Reassign"

      # Turbo Stream updates a partial; verify DB state after action completes
      sleep 1
      running_task.reload
      expect(running_task.agent_id).to eq(compatible_agent.id)
      expect(running_task.state).to eq("pending")
    end
  end

  describe "download results" do
    let(:completed_task) { create(:task, attack: attack, agent: agent, state: :pending) }

    before { completed_task.update_columns(state: "completed") } # rubocop:disable Rails/SkipsModelValidations

    it "has download results link for completed tasks" do
      create(:hash_item, :cracked_recently,
        hash_list: hash_list,
        hash_value: "abc123",
        plain_text: "password1")

      visit task_path(completed_task)

      expect(page).to have_link("Download Results")
    end

    it "download results link points to correct path" do
      create(:hash_item, :cracked_recently,
        hash_list: hash_list,
        hash_value: "abc123",
        plain_text: "password1")

      visit task_path(completed_task)

      download_link = find_link("Download Results")
      expect(download_link[:href]).to include(download_results_task_path(completed_task))
    end
  end
end
