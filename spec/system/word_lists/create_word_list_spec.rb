# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "Create word list" do
  let(:user) { create_and_sign_in_user }
  let(:form_page) { AttackResourceFormPage.new(page) }
  let(:first_project) { create(:project, name: "Project One") }
  let(:second_project) { create(:project, name: "Project Two") }
  let(:file_path) { Rails.root.join("spec/fixtures/word_lists/top-passwords.txt") }

  it_behaves_like "attack resource creation", :word_list, "Word list"
end
