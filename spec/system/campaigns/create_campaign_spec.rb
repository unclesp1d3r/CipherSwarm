# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Create campaign" do
  let(:user) { create_and_sign_in_user }
  let(:campaigns_index_page) { CampaignsIndexPage.new(page) }
  let(:project) { create(:project) }
  let!(:hash_list) { create(:hash_list, project: project) }

  before do
    user.projects << project
  end

  describe "create campaign with valid data" do
    it "creates campaign and redirects to show page" do
      campaigns_index_page.visit_page
      campaigns_index_page.click_new_campaign

      # Wait for form to be visible
      expect(page).to have_field("Name", wait: 5)

      fill_in "Name", with: "Test Campaign"
      select hash_list.name, from: "Hash list"
      click_button "Submit"

      # Wait for redirect
      expect(page).to have_content("Campaign was successfully created", wait: 10)

      campaign = Campaign.find_by(name: "Test Campaign")
      expect(campaign).to be_present
      expect(page).to have_current_path(campaign_path(campaign))
      expect(page).to have_content("Test Campaign")
    end
  end

  describe "cannot create campaign without hash lists" do
    it "shows blank slate when no hash lists available" do
      # Ensure no hash lists exist for this user
      HashList.where(project: user.projects).destroy_all

      campaigns_index_page.visit_page
      campaigns_index_page.click_new_campaign

      expect(page).to have_content("You do not have any hash lists yet")
      expect(page).to have_link("Add Hash List")
    end
  end

  describe "create campaign with validation errors" do
    it "shows validation errors for invalid data" do
      campaigns_index_page.visit_page
      campaigns_index_page.click_new_campaign

      # Wait for form to be visible
      expect(page).to have_field("Name", wait: 5)

      click_button "Submit"

      expect(page).to have_content("Name can't be blank")
    end
  end

  describe "campaign inherits project from hash list" do
    it "sets campaign project from hash list" do
      campaigns_index_page.visit_page
      campaigns_index_page.click_new_campaign

      # Wait for form to be visible
      expect(page).to have_field("Name", wait: 5)

      fill_in "Name", with: "Project Campaign"
      select hash_list.name, from: "Hash list"
      click_button "Submit"

      # Wait for redirect
      expect(page).to have_content("Campaign was successfully created", wait: 10)

      campaign = Campaign.find_by(name: "Project Campaign")
      expect(campaign).to be_present
      expect(campaign.project).to eq(hash_list.project)
    end
  end
end
