# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Campaign Creation Workflow", skip: ENV["CI"].present? do
  let(:user) { create_and_sign_in_user }
  let(:project) { create(:project) }
  let!(:hash_list) { create(:hash_list, project: project) }
  let(:campaigns_index_page) { CampaignsIndexPage.new(page) }

  before do
    user.projects << project
  end

  describe "creating a new campaign with valid data" do
    it "creates campaign and redirects to show page with success message", :aggregate_failures do
      campaigns_index_page.visit_page
      campaigns_index_page.click_new_campaign

      expect(page).to have_field("Name", wait: 5)

      fill_in "Name", with: "Integration Test Campaign"
      select hash_list.name, from: "Hash list"
      click_button "Submit"

      expect(page).to have_content("Campaign was successfully created", wait: 10)

      campaign = Campaign.find_by(name: "Integration Test Campaign")
      expect(campaign).to be_present
      expect(page).to have_current_path(campaign_path(campaign))
      expect(page).to have_content("Integration Test Campaign")
    end
  end

  describe "redirect to attack creation after campaign creation" do
    it "campaign show page offers add attack buttons", :aggregate_failures do
      campaigns_index_page.visit_page
      campaigns_index_page.click_new_campaign

      expect(page).to have_field("Name", wait: 5)

      fill_in "Name", with: "Attack Ready Campaign"
      select hash_list.name, from: "Hash list"
      click_button "Submit"

      expect(page).to have_content("Campaign was successfully created", wait: 10)

      # Campaign show page should offer attack creation
      expect(page).to have_content("The campaign is empty")
      expect(page).to have_css("a[title='Add Dictionary Attack']")
    end
  end

  describe "form validation errors" do
    it "shows validation errors for missing name" do
      campaigns_index_page.visit_page
      campaigns_index_page.click_new_campaign

      expect(page).to have_field("Name", wait: 5)
      click_button "Submit"

      expect(page).to have_content("Name can't be blank")
    end
  end

  describe "campaign inherits project from hash list" do
    it "sets campaign project correctly from selected hash list" do
      campaigns_index_page.visit_page
      campaigns_index_page.click_new_campaign

      expect(page).to have_field("Name", wait: 5)

      fill_in "Name", with: "Project Scoped Campaign"
      select hash_list.name, from: "Hash list"
      click_button "Submit"

      expect(page).to have_content("Campaign was successfully created", wait: 10)

      campaign = Campaign.find_by(name: "Project Scoped Campaign")
      expect(campaign.project).to eq(hash_list.project)
    end
  end

  describe "no hash lists available" do
    it "shows blank slate when no hash lists exist for user" do
      HashList.where(project: user.projects).destroy_all

      campaigns_index_page.visit_page
      campaigns_index_page.click_new_campaign

      expect(page).to have_content("You do not have any hash lists yet")
      expect(page).to have_link("Add Hash List")
    end
  end
end
