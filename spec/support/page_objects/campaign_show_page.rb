# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Page object for the campaign show page with nested attacks
class CampaignShowPage < BasePage
  # Visit the campaign show page
  # @param campaign [Campaign] the campaign to view
  def visit_page(campaign)
    visit campaign_path(campaign)
    self
  end

  # Click "Add Dictionary Attack" button
  def click_add_dictionary_attack
    find("a[href*='attack_mode=dictionary'][title='Add Dictionary Attack']").click
    self
  end

  # Click "Add Mask Attack" button
  def click_add_mask_attack
    find("a[href*='attack_mode=mask'][title='Add Mask Attack']").click
    self
  end

  # Click "Add Hybrid Dictionary Attack" button
  def click_add_hybrid_dictionary_attack
    find("a[href*='attack_mode=hybrid_dictionary'][title='Add Hybrid Dictionary Attack']").click
    self
  end

  # Click "Add Hybrid Mask Attack" button
  def click_add_hybrid_mask_attack
    find("a[href*='attack_mode=hybrid_mask'][title='Add Hybrid Mask Attack']").click
    self
  end

  # Check if an attack appears in the list
  # @param attack_name [String] the attack name
  # @return [Boolean] true if the attack is found
  def has_attack?(attack_name)
    has_content?(attack_name)
  end

  # Get the number of attacks displayed
  # @return [Integer] the count of attack stepper items
  def attack_count
    all(".stepper-item").count
  end

  # Check for blank slate message
  # @return [Boolean] true if blank slate is displayed
  def has_blank_slate?
    has_content?("The campaign is empty")
  end

  # Click edit campaign button
  def click_edit_campaign
    find("a[href*='/edit'][title='Edit']").click
    self
  end

  # Get attack stepper line elements
  # @return [Capybara::Result] collection of stepper item elements
  def attack_stepper_items
    all(".stepper-item")
  end
end
