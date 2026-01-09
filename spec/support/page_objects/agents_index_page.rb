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

  private

  # Scope operations to an agent card
  # @param agent_name [String] the agent name or custom label
  # @yield the block to execute within the card
  def within_agent_card(agent_name, &)
    within_section(agent_card(agent_name), &)
  end
end
