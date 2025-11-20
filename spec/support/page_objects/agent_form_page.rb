# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Page object for agent creation and editing forms
class AgentFormPage < BasePage
  # Visit the new agent page
  def visit_new_page
    visit new_agent_path
    self
  end

  # Visit the edit agent page
  # @param agent [Agent] the agent to edit
  def visit_edit_page(agent)
    visit edit_agent_path(agent)
    self
  end

  # Fill in the custom label field
  # @param label [String] the custom label
  def fill_custom_label(label)
    fill_in FormLabelsHelper::Agent.custom_label, with: label
    self
  end

  # Toggle the enabled checkbox
  def toggle_enabled
    enabled_label = FormLabelsHelper::Agent.enabled
    if has_checked_field?(enabled_label)
      uncheck enabled_label
    else
      check enabled_label
    end
    self
  end

  # Select a user from the dropdown (admin only)
  # @param user [User] the user to select
  def select_user(user)
    select user.name, from: FormLabelsHelper::Agent.user
    self
  end

  # Select projects by checking checkboxes
  # @param project_names [Array<String>] array of project names
  def select_projects(project_names)
    project_names.each do |name|
      check name
    end
    self
  end

  # Fill advanced configuration fields
  # @param config_hash [Hash] hash of config field names to values
  #   Keys should be the label strings (e.g., "Agent update interval", "Backend device")
  def fill_advanced_config(config_hash)
    config_hash.each do |field_label, value|
      fill_in field_label, with: value
    end
    self
  end

  # Submit the form
  def submit_form
    submit_primary_form
  end

  # Click the cancel link
  def click_cancel
    click_link "Cancel"
    self
  end

  # Check for validation error messages
  # @param message [String] the error message to check for
  # @return [Boolean] true if the error message is displayed
  def has_validation_error?(message)
    has_content?(message)
  end
end
