# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Create mask list" do
  let(:user) { create_and_sign_in_user }
  let(:form_page) { AttackResourceFormPage.new(page) }
  let(:first_project) { create(:project, name: "Project One") }
  let(:second_project) { create(:project, name: "Project Two") }
  let(:file_path) { Rails.root.join("spec/fixtures/mask_lists/rockyou-1-60.hcmask") }

  describe "form displays checkboxes for project selection" do
    before do
      user.projects << [first_project, second_project]
    end

    it "shows checkboxes instead of radio buttons" do
      visit new_mask_list_path

      expect(form_page.has_project_checkboxes?).to be true
      expect(form_page.has_project_radio_buttons?).to be false
    end

    it "displays accessible projects as checkboxes" do
      visit new_mask_list_path

      # Verify checkboxes exist for both projects
      expect(page).to have_field(first_project.name, type: "checkbox")
      expect(page).to have_field(second_project.name, type: "checkbox")
    end
  end

  describe "create mask list with single project" do
    before do
      user.projects << [first_project, second_project]
    end

    it "creates mask list associated with one project" do
      visit new_mask_list_path

      form_page.fill_name("Test Mask List")
      form_page.fill_description("Test description")
      form_page.attach_file(file_path)
      form_page.wait_for_upload_complete
      form_page.select_projects([first_project.name])
      form_page.submit_form

      expect(page).to have_content("Mask list was successfully created", wait: 5)

      mask_list = MaskList.find_by(name: "Test Mask List")
      expect(mask_list).to be_present
      expect(mask_list.projects).to contain_exactly(first_project)
      expect(mask_list.sensitive).to be true
    end
  end

  describe "create mask list with multiple projects" do
    before do
      user.projects << [first_project, second_project]
    end

    it "creates mask list associated with multiple projects" do
      visit new_mask_list_path

      form_page.fill_name("Multi-Project Mask List")
      form_page.fill_description("Test description")
      form_page.attach_file(file_path)
      form_page.wait_for_upload_complete
      form_page.select_projects([first_project.name, second_project.name])
      form_page.submit_form

      expect(page).to have_content("Mask list was successfully created", wait: 5)

      mask_list = MaskList.find_by(name: "Multi-Project Mask List")
      expect(mask_list).to be_present
      expect(mask_list.projects).to contain_exactly(first_project, second_project)
      expect(mask_list.sensitive).to be true
    end
  end

  describe "create mask list without project selection" do
    before do
      user.projects << [first_project, second_project]
    end

    it "creates shared mask list when no projects selected" do
      visit new_mask_list_path

      form_page.fill_name("Shared Mask List")
      form_page.fill_description("Test description")
      form_page.attach_file(file_path)
      form_page.wait_for_upload_complete
      form_page.submit_form

      expect(page).to have_content("Mask list was successfully created", wait: 5)

      mask_list = MaskList.find_by(name: "Shared Mask List")
      expect(mask_list).to be_present
      expect(mask_list.projects).to be_empty
      expect(mask_list.sensitive).to be false
    end
  end

  describe "project visibility based on user membership" do
    let(:accessible_project) { create(:project, name: "Accessible Project") }
    let(:inaccessible_project) { create(:project, name: "Inaccessible Project") }

    context "when user is member of project" do
      before do
        # Clear any existing project memberships from top-level setup
        user.projects.clear
        user.projects << accessible_project
      end

      it "displays project in checkbox list" do
        visit new_mask_list_path

        expect(page).to have_field(accessible_project.name, type: "checkbox")
      end

      it "allows creating resource with accessible project" do
        visit new_mask_list_path

        form_page.fill_name("Accessible Project Mask List")
        form_page.fill_description("Test description")
        form_page.attach_file(file_path)
        form_page.wait_for_upload_complete
        form_page.select_projects([accessible_project.name])
        form_page.submit_form

        expect(page).to have_content("Mask list was successfully created", wait: 5)

        mask_list = MaskList.find_by(name: "Accessible Project Mask List")
        expect(mask_list).to be_present
        expect(mask_list.projects).to contain_exactly(accessible_project)
      end
    end

    context "when user is not member of project" do
      before do
        # Clear any existing project memberships and ensure user is not in inaccessible_project
        user.projects.clear
      end

      it "does not display project in checkbox list" do
        visit new_mask_list_path
        expect(page).to have_content("Name", wait: 5)

        expect(page).to have_no_field(inaccessible_project.name, type: "checkbox")
      end
    end

    context "when user has no project memberships" do
      let(:user_without_projects) { create(:user) }
      let(:form_page_no_projects) { AttackResourceFormPage.new(page) }

      before do
        # Sign out current user and sign in user without projects
        sign_out(user)
        sign_in(user_without_projects)
      end

      it "displays no project checkboxes" do
        visit new_mask_list_path
        expect(page).to have_content("Name", wait: 5)

        expect(page).to have_no_css("input[type='checkbox'][name*='project_ids']")
      end

      it "allows creating shared resource without projects" do
        visit new_mask_list_path

        form_page_no_projects.fill_name("Shared Resource No Projects")
        form_page_no_projects.fill_description("Test description")
        form_page_no_projects.attach_file(file_path)
        form_page_no_projects.wait_for_upload_complete
        form_page_no_projects.submit_form

        expect(page).to have_content("Mask list was successfully created", wait: 5)

        mask_list = MaskList.find_by(name: "Shared Resource No Projects")
        expect(mask_list).to be_present
        expect(mask_list.projects).to be_empty
        expect(mask_list.sensitive).to be false
      end
    end
  end

  describe "validation errors" do
    before do
      user.projects << [first_project, second_project]
    end

    it "shows validation errors for missing required fields" do
      visit new_mask_list_path

      form_page.submit_form

      expect(form_page.has_validation_error?("Name can't be blank")).to be true
      expect(form_page.has_validation_error?("File can't be blank")).to be true
    end
  end
end
