# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Page object for the campaigns index page (Activity view)
class CampaignsIndexPage < BasePage
  # Visit the campaigns index page
  def visit_page
    visit campaigns_path
    self
  end

  # Click the "New Campaign" button
  def click_new_campaign
    click_link "New Campaign"
    self
  end

  # Check if a campaign appears in the list
  # @param campaign_name [String] the campaign name
  # @return [Boolean] true if the campaign is found
  def has_campaign?(campaign_name)
    has_content?(campaign_name)
  end

  # Get the number of campaigns displayed
  # @return [Integer] the count of campaign rows
  def campaign_count
    all("tbody tr").count
  end

  # Click on a campaign to view details
  # @param campaign_name [String] the campaign name
  def click_campaign(campaign_name)
    click_link campaign_name
    self
  end

  # Toggle the hide completed activities button
  def toggle_hide_completed
    first("a[href='/toggle_hide_completed_activities']").click
    # rubocop:enable Capybara/SpecificActions
    self
  end

  # Check if completed campaigns are hidden
  # @return [Boolean] true if the toggle indicates completed items are hidden
  def has_completed_campaigns_hidden?
    find("a[href='/toggle_hide_completed_activities']").has_css?("svg")
  end

  # Get the campaign row element
  # @param campaign_name [String] the campaign name
  # @return [Capybara::Node::Element] the campaign row element
  def campaign_row(campaign_name)
    find("tbody tr", text: campaign_name)
  end
end
