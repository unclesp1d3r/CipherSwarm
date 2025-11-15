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
  # @return [Integer] the count of agent rows
  def agent_count
    all("tbody tr").count
  end

  # Click on an agent row to view details
  # @param agent_name [String] the agent name or custom label
  def click_agent(agent_name)
    within_agent_row(agent_name) do
      find("a.btn-primary").click
    end
    self
  end

  # Click edit button for an agent
  # @param agent_name [String] the agent name or custom label
  def click_edit_agent(agent_name)
    within_agent_row(agent_name) do
      find("a.btn-warning").click
    end
    self
  end

  # Click delete button for an agent and confirm
  # @param agent_name [String] the agent name or custom label
  def click_delete_agent(agent_name)
    within_agent_row(agent_name) do
      accept_confirm do
        first("button.btn-danger").click
        # rubocop:enable Capybara/SpecificActions
      end
    end
    self
  end

  # Get the agent row element for assertions
  # @param agent_name [String] the agent name or custom label
  # @return [Capybara::Node::Element] the agent row element
  def agent_row(agent_name)
    find("tbody tr", text: agent_name)
  end

  # Check for empty state message
  # @return [Boolean] true if no agents message is displayed
  def has_no_agents_message?
    has_content?("You do not have any agents")
  end

  private

  # Scope operations to an agent row
  # @param agent_name [String] the agent name or custom label
  # @yield the block to execute within the row
  def within_agent_row(agent_name, &)
    within_section(agent_row(agent_name), &)
  end
end
