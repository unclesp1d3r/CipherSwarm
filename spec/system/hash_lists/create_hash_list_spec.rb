# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Create hash list" do
  let(:user) { create_and_sign_in_user }
  let(:hash_list_form) { HashListFormPage.new(page) }
  let(:project) { create(:project) }
  let!(:hash_type) { create(:md5) }
  let(:file_path) { Rails.root.join("spec/fixtures/hash_lists/example_hashes.txt") }

  before do
    user.projects << project
  end

  describe "create hash list with file upload" do
    it "creates hash list and uploads file" do
      visit hash_lists_path
      find("a[href='#{new_hash_list_path}']").click

      hash_list_form.fill_name("Test Hash List")
      hash_list_form.select_hash_type(hash_type.name)
      hash_list_form.select_project(project.name)
      hash_list_form.attach_file(file_path)
      hash_list_form.wait_for_upload_complete
      hash_list_form.submit_form

      if page.has_content?("error") || page.has_content?("prohibited")
        puts "DEBUG: Validation errors found:"
        puts page.text
      end

      # Wait for redirect to hash list show page
      hash_list = HashList.find_by(name: "Test Hash List")
      expect(hash_list).to be_present
      expect(page).to have_current_path(hash_list_path(hash_list), wait: 5)
      expect_flash_message("Hash list was successfully created")
      expect(page).to have_content("Test Hash List")
    end
  end

  describe "create hash list with validation errors" do
    it "shows validation errors for missing required fields" do
      visit hash_lists_path
      find("a[href='#{new_hash_list_path}']").click

      hash_list_form.submit_form

      expect(hash_list_form.has_validation_error?("Name can't be blank")).to be true
      expect(hash_list_form.has_validation_error?("File can't be blank")).to be true
    end
  end

  describe "hash list file processing" do
    before do
      ActiveJob::Base.queue_adapter = :test
    end

    it "processes file and creates hash items" do
      visit hash_lists_path
      find("a[href='#{new_hash_list_path}']").click

      hash_list_form.fill_name("Processed Hash List")
      hash_list_form.select_hash_type(hash_type.name)
      hash_list_form.select_project(project.name)
      hash_list_form.attach_file(file_path)
      hash_list_form.wait_for_upload_complete
      hash_list_form.submit_form

      # Wait for redirect and hash list creation
      expect(page).to have_content("Hash list was successfully created", wait: 5)
      hash_list = HashList.find_by(name: "Processed Hash List")
      expect(hash_list).to be_present
      expect(hash_list.file).to be_attached

      # Wait for background job to process (or use inline jobs in test)
      perform_enqueued_jobs

      hash_list.reload
      expect(hash_list.processed).to be true
      expect(hash_list.hash_items_count).to be > 0
    end
  end
end
