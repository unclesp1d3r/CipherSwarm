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

  # Check for ETA summary alert
  # @return [Boolean] true if ETA summary is present
  def has_eta_summary?
    has_css?("#campaign-eta-summary[role='region'][aria-label='Campaign ETA summary']")
  end

  # Get current attack ETA text
  # @return [String] current attack ETA text
  def current_attack_eta
    find_by_id('current-eta-text').text
  end

  # Get total campaign ETA text
  # @return [String] total campaign ETA text
  def total_campaign_eta
    find_by_id('total-eta-text').text
  end

  # Check if progress bar exists for an attack
  # @param attack_name [String] name of the attack
  # @return [Boolean] true if progress bar exists
  def has_progress_bar?(attack_name)
    has_css?(".stepper-item", text: attack_name) &&
      find(".stepper-item", text: attack_name).has_css?(".progress")
  end

  # Get progress percentage for an attack
  # @param attack_name [String] name of the attack
  # @return [Integer] progress percentage
  def attack_progress_percentage(attack_name)
    item = find(".stepper-item", text: attack_name)
    bar = item.find(".progress-bar")
    bar[:"aria-valuenow"].to_i
  end

  # Get ETA text for an attack from progress component
  # @param attack_name [String] name of the attack
  # @return [String] ETA text or empty string
  def attack_eta_text(attack_name)
    item = find(".stepper-item", text: attack_name)
    if item.has_css?(".text-muted.small")
      item.find(".text-muted.small").text
    else
      ""
    end
  end

  # Get status badge text for an attack
  # @param attack_name [String] name of the attack
  # @return [String] status badge text
  def attack_status_badge(attack_name)
    item = find(".stepper-item", text: attack_name)
    item.find(".badge").text
  end

  # Click error indicator for an attack
  # @param attack_name [String] name of the attack
  def click_error_indicator(attack_name)
    item = find(".stepper-item", text: attack_name)
    item.find("button[aria-label^='View error details']").click
  end

  # Check if error modal is present
  # @param attack_id [Integer] ID of the attack
  # @return [Boolean] true if modal is present
  def has_error_modal?(attack_id)
    has_css?("#error-modal-attack-#{attack_id}", visible: true)
  end

  # Get error modal severity
  # @param attack_id [Integer] ID of the attack
  # @return [String] severity text
  def error_modal_severity(attack_id)
    find("#error-modal-attack-#{attack_id} .badge").text
  end

  # Get error modal message
  # @param attack_id [Integer] ID of the attack
  # @return [String] error message text
  def error_modal_message(attack_id)
    within("#error-modal-attack-#{attack_id} .modal-body") do
      find("div[aria-label='Error message'] span").text
    end
  end

  # Expand recent cracks section
  def expand_recent_cracks
    click_button "Recent Cracks"
  end

  # Check if recent cracks section is present
  # @return [Boolean] true if section exists
  def has_recent_cracks_section?
    has_css?("div[role='region'][aria-label='Recent cracks section']")
  end

  # Get recent cracks count badge value
  # @return [String] count text
  def recent_cracks_count
    within("div[role='region'][aria-label='Recent cracks section']") do
      find(".badge").text
    end
  end

  # Get recent cracks table rows
  # @return [Capybara::Result] collection of table rows
  def recent_cracks_table_rows
    all("#recent-cracks-table tbody tr")
  end

  # Check if error log section is present
  # @return [Boolean] true if section exists
  def has_error_log_section?
    has_css?("div[role='region'][aria-label='Campaign error log']")
  end

  # Get error log table rows
  # @return [Capybara::Result] collection of table rows
  def error_log_table_rows
    all("#error-log-table tbody tr")
  end

  # Check for no errors message
  # @return [Boolean] true if blank slate present in error log
  def has_no_errors_message?
    within("div[role='region'][aria-label='Campaign error log']") do
      has_content?("No Errors")
    end
  end

  # Check for no recent cracks message
  # @return [Boolean] true if blank slate present in recent cracks
  def has_no_recent_cracks_message?
    within("div[role='region'][aria-label='Recent cracks section']") do
      has_content?("No Recent Cracks")
    end
  end

  # Wait for ETA summary Turbo Frame to load
  def wait_for_eta_summary_loaded
    wait_for_turbo_frame("campaign_eta_summary")
  end

  # Wait for recent cracks Turbo Frame to load
  def wait_for_recent_cracks_loaded
    wait_for_turbo_frame("campaign_recent_cracks")
  end

  # Wait for error log Turbo Frame to load
  def wait_for_error_log_loaded
    wait_for_turbo_frame("campaign_error_log")
  end

  private

  # Wait for turbo frame to complete loading
  # @param frame_id [String] ID of the turbo frame
  def wait_for_turbo_frame(frame_id)
    session.assert_no_selector("turbo-frame##{frame_id}[busy]", wait: 5)
  end
end
