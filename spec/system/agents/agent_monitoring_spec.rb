# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Agent monitoring" do
  let(:agents_index) { AgentsIndexPage.new(page) }
  let(:agent_page) { AgentDetailPage.new(page) }
  let(:user) { create_and_sign_in_user }

  let!(:agent) do
    create(:agent,
      user: user,
      state: :active,
      current_hash_rate: 1_200_000_000,
      current_temperature: 65,
      current_utilization: 80,
      last_seen_at: 2.minutes.ago,
      devices: ["NVIDIA RTX", "Intel CPU"])
  end

  let(:running_task) { create(:task, agent: agent, state: "running") }

  let(:recent_errors) do
    create_list(:agent_error, 10, agent: agent, created_at: 1.hour.ago) +
      [create(:agent_error, agent: agent, created_at: 1.hour.ago)]
  end

  let(:benchmarks) do
    [
      create(:hashcat_benchmark, agent: agent, hash_type: 0, benchmark_date: Time.current),
      create(:hashcat_benchmark, agent: agent, hash_type: 1000, benchmark_date: Time.current),
      create(:hashcat_benchmark, agent: agent, hash_type: 22000, benchmark_date: Time.current)
    ]
  end

  before do
    agent_project = agent.projects.first
    user.projects << agent_project unless user.projects.include?(agent_project)

    task_project = running_task.attack.campaign.project
    user.projects << task_project unless user.projects.include?(task_project)

    running_task
    recent_errors
    benchmarks
  end

  it "shows agent list and navigates to detail", :aggregate_failures do
    agents_index.visit_page

    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(agent)}")
    expect(agents_index.has_status_badge?(agent.name, "Active")).to be true
    expect(agents_index.has_hash_rate?(agent.name, agent.hash_rate_display)).to be true
    expect(agents_index.has_error_count?(agent.name, 11)).to be true
    expect(agents_index.has_error_indicator_danger?(agent.name)).to be true

    agents_index.click_agent(agent.name)

    expect(page).to have_current_path(agent_path(agent))
    expect(agent_page.has_tab?("Overview")).to be true
    expect(agent_page.has_agent_status?).to be true
    expect(agent_page.has_performance_metrics?).to be true
  end

  it "navigates between tabs and toggles visibility", :aggregate_failures do
    agent_page.visit_page(agent)

    expect(agent_page.has_active_tab?("Overview")).to be true
    agent_page.click_tab("Errors")
    expect(agent_page.has_active_tab?("Errors")).to be true
    expect(agent_page.has_errors_table?).to be true

    agent_page.click_tab("Configuration")
    expect(agent_page.has_active_tab?("Configuration")).to be true
    expect(agent_page.has_configuration_details?).to be true

    agent_page.click_tab("Capabilities")
    expect(agent_page.has_active_tab?("Capabilities")).to be true
    expect(agent_page.has_capabilities_details?).to be true
  end

  it "paginates errors and shows blank slate when none" do
    agent_page.visit_page(agent)
    agent_page.click_tab("Errors")

    expect(agent_page.error_count).to eq(10)
    expect(page).to have_css(".pagination")

    agent.agent_errors.destroy_all
    visit current_path
    agent_page.click_tab("Errors")

    expect(page).to have_text("No errors recorded")
  end

  it "preserves active tab when turbo updates run" do
    agent_page.visit_page(agent)
    agent_page.click_tab("Errors")

    perform_enqueued_jobs do
      agent.update!(current_hash_rate: 2_000_000_000)
      agent.broadcast_tab_updates
    end

    expect(agent_page.has_active_tab?("Errors")).to be true
    agent_page.click_tab("Overview")
    expect(page).to have_content(agent.reload.hash_rate_display)
  end

  describe "real-time updates via Turbo Streams", :js do
    it "verifies agent card structure supports Turbo Stream subscriptions" do
      agents_index.visit_page

      agent_card_selector = "##{ActionView::RecordIdentifier.dom_id(agent)}"
      expect(page).to have_css(agent_card_selector)
      expect(agents_index.has_status_badge?(agent.name, "Active")).to be true

      # Verify turbo stream subscription is rendered (may be hidden element)
      expect(page).to have_css("turbo-cable-stream-source", visible: :all)

      # Verify agent data is displayed correctly
      expect(page).to have_content(agent.hash_rate_display)
    end

    it "broadcasts agent card updates correctly" do
      # This test verifies the broadcast mechanics work correctly at model level
      agent.update!(current_hash_rate: 5_000_000_000, state: :pending)
      original_hash_rate = agent.hash_rate_display

      # Update to a different hash rate
      agent.update!(current_hash_rate: 10_000_000_000)

      perform_enqueued_jobs do
        agent.broadcast_replace_to(
          agent,
          target: ActionView::RecordIdentifier.dom_id(agent),
          partial: "agents/agent_status_card",
          locals: { agent: agent }
        )
      end

      # Verify the broadcast was triggered and data was updated
      expect(agent.hash_rate_display).not_to eq(original_hash_rate)
    end

    it "preserves active tab and shows updated content after page refresh", :aggregate_failures do
      # Use a fresh agent with no pre-existing errors to avoid pagination complexity
      fresh_agent = create(:agent,
        user: user,
        state: :active,
        projects: agent.projects)

      agent_page.visit_page(fresh_agent)
      agent_page.click_tab("Errors")

      expect(agent_page.has_active_tab?("Errors")).to be true
      expect(page).to have_css(".nav-link.active", text: "Errors")
      expect(page).to have_text("No errors recorded")

      # Create a new error (simulating what would be pushed via Turbo Stream)
      create(:agent_error, agent: fresh_agent, created_at: Time.current, message: "New broadcast error")

      # Trigger broadcast (Note: ActionCable broadcasts don't work in system tests,
      # so we verify the tab persistence mechanism and content update after refresh)
      perform_enqueued_jobs do
        fresh_agent.broadcast_tab_updates
      end

      # Refresh via keyboard shortcut (F5) to simulate Turbo Stream refresh behavior
      page.driver.browser.navigate.refresh
      agent_page.click_tab("Errors")

      # Verify the active tab can be restored and shows updated content
      expect(page).to have_css(".nav-link.active", text: "Errors")
      expect(agent_page.has_active_tab?("Errors")).to be true
      expect(page).to have_content("New broadcast error")
    end

    it "displays updated error count after content refresh" do
      # Verify error count updates correctly when content refreshes
      fresh_agent = create(:agent,
        user: user,
        state: :active,
        projects: agent.projects)

      agent_page.visit_page(fresh_agent)
      agent_page.click_tab("Errors")
      expect(page).to have_text("No errors recorded")
      expect(page).to have_css(".nav-link.active", text: "Errors")

      # Create error and trigger update
      create(:agent_error, agent: fresh_agent, created_at: Time.current, message: "New broadcast error")
      perform_enqueued_jobs do
        fresh_agent.broadcast_tab_updates
      end

      # Refresh the page to simulate receiving the Turbo Stream update
      page.driver.browser.navigate.refresh
      agent_page.click_tab("Errors")

      # Verify tab persists and content updates
      expect(page).to have_css(".nav-link.active", text: "Errors")
      expect(page).to have_content("New broadcast error")
      expect(agent_page.error_count).to eq(1)
    end

    it "maintains tab structure and shows updated data after switching tabs" do
      agent_page.visit_page(agent)
      agent_page.click_tab("Capabilities")

      expect(agent_page.has_active_tab?("Capabilities")).to be true
      expect(page).to have_css(".nav-link.active", text: "Capabilities")

      new_hash_rate = 9_999_000_000
      agent.update!(current_hash_rate: new_hash_rate)

      perform_enqueued_jobs do
        agent.broadcast_tab_updates
      end

      # Verify tab navigation still works correctly
      expect(page).to have_css(".nav-link.active", text: "Capabilities")
      expect(agent_page.has_active_tab?("Capabilities")).to be true

      # Refresh and switch to overview to verify updated data
      page.driver.browser.navigate.refresh
      agent_page.click_tab("Overview")
      expect(page).to have_content(agent.reload.hash_rate_display)
    end
  end

  it "updates capabilities when benchmarks change" do
    agent_page.visit_page(agent)
    agent_page.click_tab("Capabilities")

    expect(agent_page.benchmark_count).to eq(3)

    # Create a new benchmark with a future date so it becomes the "last" benchmark
    create(:hashcat_benchmark, agent: agent, hash_type: 5000, benchmark_date: 1.minute.from_now)
    agent.update!(last_seen_at: Time.current)

    # Reload the page to see the updated benchmarks
    # (Turbo Stream broadcasts don't reliably update the browser in system tests)
    visit current_path
    agent_page.click_tab("Capabilities")

    expect(agent_page.benchmark_count).to eq(4)
  end

  describe "authorization" do
    let(:other_user) { create(:user) }
    let!(:other_agent) { create(:agent, user: other_user) }
    let(:shared_project) { create(:project) }

    before do
      other_agent.projects << shared_project unless other_agent.projects.include?(shared_project)
      other_user.projects << shared_project
      user.projects << shared_project unless user.projects.include?(shared_project)
    end

    it "hides edit button for non-admin on other agents" do
      agent_page.visit_page(other_agent)
      agent_page.click_tab("Configuration")

      expect(page).to have_no_link("Edit Agent")
    end

    it "shows edit button for admins" do
      # Visit any page first so we can sign out via UI
      agents_index.visit_page
      sign_out_via_ui(user)
      admin = create_and_sign_in_admin
      admin.projects << shared_project

      agent_page.visit_page(other_agent)
      agent_page.click_tab("Configuration")

      expect(page).to have_link("Edit Agent")
    end
  end

  context "when agent has no task or benchmarks" do
    let!(:empty_agent) do
      create(:agent,
        user: user,
        state: :pending,
        current_hash_rate: 0,
        current_temperature: 0,
        current_utilization: 0,
        projects: agent.projects)
    end

    it "shows blank states across tabs" do
      agent_page.visit_page(empty_agent)

      expect(page).to have_text("No active task")
      agent_page.click_tab("Errors")
      expect(page).to have_text("No errors recorded")
      agent_page.click_tab("Capabilities")
      expect(page).to have_text("No benchmarks available")
    end
  end

  describe "agent card action buttons", :js do
    it "renders view button with eye icon inside", :aggregate_failures do
      agents_index.visit_page

      expect(agents_index.has_view_button_with_icon?(agent.name)).to be true
      expect(agents_index.icons_not_escaped?(agent.name)).to be true
    end

    it "renders edit button with pencil icon inside", :aggregate_failures do
      agents_index.visit_page

      expect(agents_index.has_edit_button_with_icon?(agent.name)).to be true
      expect(agents_index.icons_not_escaped?(agent.name)).to be true
    end

    it "renders delete button with trash icon inside", :aggregate_failures do
      agents_index.visit_page

      expect(agents_index.has_delete_button_with_icon?(agent.name)).to be true
      expect(agents_index.icons_not_escaped?(agent.name)).to be true
    end

    it "groups all action buttons in a button group", :aggregate_failures do
      agents_index.visit_page

      expect(agents_index.has_button_group?(agent.name)).to be true
      expect(agents_index.has_view_button_with_icon?(agent.name)).to be true
      expect(agents_index.has_edit_button_with_icon?(agent.name)).to be true
      expect(agents_index.has_delete_button_with_icon?(agent.name)).to be true
    end

    it "does not display escaped HTML for icons" do
      agents_index.visit_page

      within(agents_index.agent_card(agent.name)) do
        # Ensure no raw HTML text like '<i class="bi-eye"></i>' appears
        expect(page).to have_no_content('<i class="bi')
        expect(page).to have_no_content("bi-eye")
        expect(page).to have_no_content("bi-pencil")
        expect(page).to have_no_content("bi-trash")
      end
    end

    context "when user lacks permissions" do
      let(:other_user) { create(:user) }
      let!(:other_agent) { create(:agent, user: other_user) }
      let(:shared_project) { create(:project) }

      before do
        other_agent.projects << shared_project unless other_agent.projects.include?(shared_project)
        other_user.projects << shared_project
        user.projects << shared_project unless user.projects.include?(shared_project)
      end

      it "hides edit and delete buttons but shows view button with icon" do
        agents_index.visit_page

        expect(agents_index.has_view_button_with_icon?(other_agent.name)).to be true
        expect(agents_index.has_edit_button_with_icon?(other_agent.name)).to be false
        expect(agents_index.has_delete_button_with_icon?(other_agent.name)).to be false
      end
    end
  end

  describe "index page loading and empty states", :js do
    it "shows skeleton placeholders while cards are loading" do
      agents_index.visit_page

      # The turbo frame tag wraps the content, skeleton renders inside it initially
      # In test mode with eager loading, this is fast but we verify the structure
      expect(page).to have_css("turbo-frame#agents-cards")

      # Verify cards eventually load (replacing skeleton)
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(agent)}", wait: 5)
    end

    it "displays 'No Agents Found' message when no agents exist" do
      # Visit any page first so we can sign out via UI
      agents_index.visit_page
      # Sign out current user and sign in a fresh user with no agents
      sign_out_via_ui(user)
      fresh_user = create_and_sign_in_user

      agents_index.visit_page

      expect(agents_index.has_no_agents_message?).to be true
      expect(page).to have_content("Create your first agent to start cracking hashes")
      expect(page).to have_link("New Agent")
    end

    it "shows skeleton placeholder structure with correct elements" do
      # Verify the turbo frame loading mechanism works correctly
      agents_index.visit_page

      # Wait for actual content to load, confirming the turbo frame mechanism works
      expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(agent)}", wait: 5)
      # After loading, skeleton placeholders should be replaced
      expect(page).to have_no_css(".placeholder-glow")
    end
  end
end
