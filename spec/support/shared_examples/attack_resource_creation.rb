# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Shared examples for attack resource creation (word lists, rule lists, mask lists)
# Usage:
#   it_behaves_like "attack resource creation", :word_list, "Word list"
#
# @param resource_type [Symbol] the factory/model symbol (:word_list, :rule_list, :mask_list)
# @param resource_name [String] the human-readable name ("Word list", "Rule list", "Mask list")
RSpec.shared_examples "attack resource creation" do |resource_type, resource_name|
  let(:resource_class) { resource_type.to_s.classify.constantize }
  let(:new_path) { send("new_#{resource_type}_path") }
  let(:success_message) { "#{resource_name} was successfully created" }

  describe "form displays checkboxes for project selection" do
    before do
      user.projects << [first_project, second_project]
    end

    it "allows selecting multiple projects simultaneously" do
      visit new_path

      form_page.select_projects([first_project.name, second_project.name])

      expect(form_page.has_checked_field?(first_project.name)).to be true
      expect(form_page.has_checked_field?(second_project.name)).to be true
    end

    it "displays accessible projects as checkboxes" do
      visit new_path

      expect(page).to have_field(first_project.name, type: "checkbox")
      expect(page).to have_field(second_project.name, type: "checkbox")
    end
  end

  describe "create #{resource_name.downcase} with single project" do
    before do
      user.projects << [first_project, second_project]
    end

    it "creates #{resource_name.downcase} associated with one project" do
      visit new_path

      form_page.fill_name("Test #{resource_name}")
      form_page.fill_description("Test description")
      form_page.attach_file(file_path)
      form_page.wait_for_upload_complete
      form_page.select_projects([first_project.name])
      form_page.submit_form

      expect(page).to have_content(success_message, wait: 5)

      resource = resource_class.find_by(name: "Test #{resource_name}")
      expect(resource).to be_present
      expect(resource.projects).to contain_exactly(first_project)
      expect(resource.sensitive).to be true
      expect(resource.creator).to eq(user)
    end
  end

  describe "create #{resource_name.downcase} with multiple projects" do
    before do
      user.projects << [first_project, second_project]
    end

    it "creates #{resource_name.downcase} associated with multiple projects" do
      visit new_path

      form_page.fill_name("Multi-Project #{resource_name}")
      form_page.fill_description("Test description")
      form_page.attach_file(file_path)
      form_page.wait_for_upload_complete
      form_page.select_projects([first_project.name, second_project.name])
      form_page.submit_form

      expect(page).to have_content(success_message, wait: 5)

      resource = resource_class.find_by(name: "Multi-Project #{resource_name}")
      expect(resource).to be_present
      expect(resource.projects).to contain_exactly(first_project, second_project)
      expect(resource.sensitive).to be true
    end
  end

  describe "create #{resource_name.downcase} without project selection" do
    before do
      user.projects << [first_project, second_project]
    end

    it "creates shared #{resource_name.downcase} when no projects selected" do
      visit new_path

      form_page.fill_name("Shared #{resource_name}")
      form_page.fill_description("Test description")
      form_page.attach_file(file_path)
      form_page.wait_for_upload_complete
      form_page.submit_form

      expect(page).to have_content(success_message, wait: 5)

      resource = resource_class.find_by(name: "Shared #{resource_name}")
      expect(resource).to be_present
      expect(resource.projects).to be_empty
      expect(resource.sensitive).to be false
    end
  end

  describe "project visibility based on user membership" do
    let(:accessible_project) { create(:project, name: "Accessible Project") }
    let(:inaccessible_project) { create(:project, name: "Inaccessible Project") }

    context "when user is member of project" do
      before do
        user.projects.clear
        user.projects << accessible_project
      end

      it "displays project in checkbox list" do
        visit new_path

        expect(page).to have_field(accessible_project.name, type: "checkbox")
      end

      it "allows creating resource with accessible project" do
        visit new_path

        form_page.fill_name("Accessible Project #{resource_name}")
        form_page.fill_description("Test description")
        form_page.attach_file(file_path)
        form_page.wait_for_upload_complete
        form_page.select_projects([accessible_project.name])
        form_page.submit_form

        expect(page).to have_content(success_message, wait: 5)

        resource = resource_class.find_by(name: "Accessible Project #{resource_name}")
        expect(resource).to be_present
        expect(resource.projects).to contain_exactly(accessible_project)
      end
    end

    context "when user is not member of project" do
      before do
        user.projects.clear
      end

      it "does not display project in checkbox list" do
        visit new_path
        expect(page).to have_content("Name", wait: 5)

        expect(page).to have_no_field(inaccessible_project.name, type: "checkbox")
      end
    end

    context "when user has no project memberships" do
      let(:user_without_projects) { create(:user) }
      let(:form_page_no_projects) { AttackResourceFormPage.new(page) }

      before do
        sign_out(user)
        sign_in(user_without_projects)
      end

      it "displays no project checkboxes" do
        visit new_path
        expect(page).to have_content("Name", wait: 5)

        expect(page).to have_no_css("input[type='checkbox'][name*='project_ids']")
      end

      it "allows creating shared resource without projects" do
        visit new_path

        form_page_no_projects.fill_name("Shared Resource No Projects")
        form_page_no_projects.fill_description("Test description")
        form_page_no_projects.attach_file(file_path)
        form_page_no_projects.wait_for_upload_complete
        form_page_no_projects.submit_form

        expect(page).to have_content(success_message, wait: 5)

        resource = resource_class.find_by(name: "Shared Resource No Projects")
        expect(resource).to be_present
        expect(resource.projects).to be_empty
        expect(resource.sensitive).to be false
      end
    end
  end

  describe "validation errors" do
    before do
      user.projects << [first_project, second_project]
    end

    it "shows validation errors for missing required fields" do
      visit new_path

      form_page.submit_form

      expect(form_page.has_validation_error?("Name can't be blank")).to be true
      expect(form_page.has_validation_error?("File can't be blank")).to be true
    end
  end
end
