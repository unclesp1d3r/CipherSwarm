# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Page object for the agents index page
class AgentsIndexPage < BasePage
  # Visit the agents index page
  def visit_page
    visit agents_path
    self
  end

  # Click the "New Agent" button
  def click_new_agent
    find("a[title='New Agent']").click
    self
  end

  # Check if an agent appears in the list
  # @param agent_name [String] the agent name or custom label to look for
  # @return [Boolean] true if the agent is found
  def has_agent?(agent_name)
    has_content?(agent_name)
  end

  # Get the number of agents displayed in the list
  # @return [Integer] the count of agent cards
  def agent_count
    all("div[id^='agent_']").count
  end

  # Click on an agent card to view details
  # @param agent_name [String] the agent name or custom label
  def click_agent(agent_name)
    within_agent_card(agent_name) do
      find("a.btn-primary").click
    end
    self
  end

  # Click edit button for an agent
  # @param agent_name [String] the agent name or custom label
  def click_edit_agent(agent_name)
    within_agent_card(agent_name) do
      find("a.btn-warning").click
    end
    self
  end

  # Click delete button for an agent and confirm
  # @param agent_name [String] the agent name or custom label
  def click_delete_agent(agent_name)
    within_agent_card(agent_name) do
      accept_confirm do
        click_button("Delete Agent")
      end
    end
    self
  end

  # Get the agent card element for assertions
  # @param agent_name [String] the agent name or custom label
  # @return [Capybara::Node::Element] the agent card wrapper element
  def agent_card(agent_name)
    find("div[id^='agent_']", text: agent_name)
  end

  # Alias for backward compatibility with tests
  alias agent_row agent_card

  # Check for empty state message
  # @return [Boolean] true if no agents message is displayed
  def has_no_agents_message?
    has_content?("No Agents Found")
  end

  # Check if the agent card shows the status badge with the expected state
  # @param agent_name [String] the agent name or custom label
  # @param state [String] the expected state text (e.g., "Active", "Pending")
  # @return [Boolean] true if the status badge displays the expected state
  def has_status_badge?(agent_name, state)
    within_agent_card(agent_name) do
      has_css?(".badge", text: state)
    end
  end

  # Check if the agent card shows the error indicator with the expected count
  # @param agent_name [String] the agent name or custom label
  # @param count [Integer] the expected error count
  # @return [Boolean] true if the error indicator displays the expected count
  def has_error_count?(agent_name, count)
    within_agent_card(agent_name) do
      has_content?("Errors (24h): #{count}")
    end
  end

  # Check if the agent card shows a danger-styled error indicator (positive error count)
  # @param agent_name [String] the agent name or custom label
  # @return [Boolean] true if the error indicator has the danger text class
  def has_error_indicator_danger?(agent_name)
    within_agent_card(agent_name) do
      has_css?(".text-danger", text: /Errors/)
    end
  end

  # Check if the agent card shows the hash rate display
  # @param agent_name [String] the agent name or custom label
  # @param hash_rate [String] the expected hash rate display text
  # @return [Boolean] true if the hash rate displays the expected value
  def has_hash_rate?(agent_name, hash_rate)
    within_agent_card(agent_name) do
      has_content?("Hash Rate: #{hash_rate}")
    end
  end

  # Check if skeleton loading placeholders are displayed
  # @return [Boolean] true if skeleton placeholders are visible
  def has_skeleton_loading?
    has_css?(".placeholder-glow")
  end

  # Check if the agent card has a view button with icon
  # @param agent_name [String] the agent name or custom label
  # @return [Boolean] true if view button contains the eye icon
  def has_view_button_with_icon?(agent_name)
    within_agent_card(agent_name) do
      has_css?("a.btn-primary i.bi-eye")
    end
  end

  # Check if the agent card has an edit button with icon
  # @param agent_name [String] the agent name or custom label
  # @return [Boolean] true if edit button contains the pencil icon
  def has_edit_button_with_icon?(agent_name)
    within_agent_card(agent_name) do
      has_css?("a.btn-warning i.bi-pencil")
    end
  end

  # Check if the agent card has a delete button with icon
  # @param agent_name [String] the agent name or custom label
  # @return [Boolean] true if delete button contains the trash icon
  def has_delete_button_with_icon?(agent_name)
    within_agent_card(agent_name) do
      has_css?("button.btn-danger i.bi-trash")
    end
  end

  # Check if all action buttons are in a button group
  # @param agent_name [String] the agent name or custom label
  # @return [Boolean] true if buttons are within a button group
  def has_button_group?(agent_name)
    within_agent_card(agent_name) do
      has_css?(".btn-group")
    end
  end

  # Check if button icons render correctly (not escaped as text)
  # @param agent_name [String] the agent name or custom label
  # @return [Boolean] true if no escaped icon HTML is visible as text
  def icons_not_escaped?(agent_name)
    within_agent_card(agent_name) do
      !has_content?('<i class="bi')
    end
  end

  private

  # Scope operations to an agent card
  # @param agent_name [String] the agent name or custom label
  # @yield the block to execute within the card
  def within_agent_card(agent_name, &)
    within_section(agent_card(agent_name), &)
  end
end
