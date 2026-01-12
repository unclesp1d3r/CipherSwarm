# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Page object for hash list creation and editing with file upload
class HashListFormPage < BasePage
  # Visit the new hash list page
  def visit_new_page
    visit new_hash_list_path
    self
  end

  # Visit the edit hash list page
  # @param hash_list [HashList] the hash list to edit
  def visit_edit_page(hash_list)
    visit edit_hash_list_path(hash_list)
    self
  end

  # Fill in the name field
  # @param name [String] the hash list name
  def fill_name(name)
    fill_in "Name", with: name
    self
  end

  # Attach a hash list file
  # @param file_path [String] the path to the file to attach
  def attach_file(file_path)
    session.attach_file("File", file_path)
    self
  end

  # Select hash type from dropdown
  # @param hash_type_name [String] the hash type name to select
  def select_hash_type(hash_type_name)
    select hash_type_name, from: "Hash type"
    self
  end

  # Select project from dropdown
  # @param project_name [String] the project name to select
  def select_project(project_name)
    select project_name, from: "Project"
    self
  end

  # Fill in the separator field
  # @param separator [String] the separator character
  def fill_separator(separator)
    fill_in "Separator", with: separator
    self
  end

  # Submit the form
  def submit_form
    submit_primary_form
  end

  # Wait for direct upload to complete
  def wait_for_upload_complete
    # Wait for upload to complete by checking for absence of pending indicator
    session.has_no_css?(".direct-upload--pending", wait: 10)
    self
  end

  # Check for validation error messages
  # @param message [String] the error message to check for
  # @return [Boolean] true if the error message is displayed
  def has_validation_error?(message)
    has_content?(message)
  end
end
