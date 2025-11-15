# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Add attack to campaign" do
  let(:user) { create_and_sign_in_user }
  let(:project) { create(:project) }
  let(:campaign) { create(:campaign, project: project) }
  let(:campaign_show_page) { CampaignShowPage.new(page) }
  let(:word_list) { create(:word_list, creator: user) }

  before do
    user.projects << project
    project.word_lists << word_list
  end

  describe "add dictionary attack" do
    it "creates dictionary attack and displays in campaign" do
      campaign_show_page.visit_page(campaign)
      campaign_show_page.click_add_dictionary_attack

      fill_in "Name", with: "Dictionary Attack"
      select word_list.name, from: "Word list"
      click_button "Submit"

      expect(page).to have_current_path(campaign_path(campaign))
      expect_flash_message("Attack was successfully created")
      expect(page).to have_content("Dictionary Attack")
    end
  end

  describe "add mask attack" do
    it "creates mask attack with mask pattern" do
      campaign_show_page.visit_page(campaign)
      campaign_show_page.click_add_mask_attack

      fill_in "Name", with: "Mask Attack"
      fill_in "Mask", with: "?a?a?a?a?a?a"
      click_button "Submit"

      expect(page).to have_current_path(campaign_path(campaign))
      expect(page).to have_content("Mask Attack")
    end
  end

  describe "attack creation with validation errors" do
    it "shows validation errors for missing required fields" do
      campaign_show_page.visit_page(campaign)
      campaign_show_page.click_add_dictionary_attack

      fill_in "Name", with: "Invalid Attack"
      click_button "Submit"

      expect(page).to have_content("Word list can't be blank")
    end
  end

  describe "attack form shows mode-specific fields" do
    it "displays dictionary attack fields" do
      campaign_show_page.visit_page(campaign)
      campaign_show_page.click_add_dictionary_attack

      expect(page).to have_field("Word list")
      expect(page).to have_field("Rule list")
    end

    it "displays mask attack fields" do
      campaign_show_page.visit_page(campaign)
      campaign_show_page.click_add_mask_attack

      expect(page).to have_field("Mask")
      expect(page).to have_field("Mask list")
    end
  end
end
