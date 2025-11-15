# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe "View hash list" do
  let(:user) { create_and_sign_in_user }
  let(:project) { create(:project) }
  let!(:hash_list) { create(:hash_list, project: project, processed: true) }

  before do
    user.projects << project
  end

  describe "view hash list details" do
    it "displays hash list information" do
      visit hash_list_path(hash_list)

      expect(page).to have_content(hash_list.name)
      expect(page).to have_content(hash_list.hash_type.name)
      expect(page).to have_content(hash_list.project.name)
    end
  end

  describe "view hash items" do
    # rubocop:disable RSpec/LetSetup
    let!(:hash_item) { create(:hash_item, hash_list: hash_list, hash_value: "5f4dcc3b5aa765d61d8327deb882cf99") }
    # rubocop:enable RSpec/LetSetup

    it "displays hash items in the list" do
      visit hash_list_path(hash_list)

      expect(page).to have_table
      expect(page).to have_content("Hash")
      expect(page).to have_content("Plain Text")
    end
  end

  describe "authorization" do
    let(:other_project) { create(:project) }
    let(:other_hash_list) { create(:hash_list, project: other_project) }
    let(:other_user) { create(:user) }

    it "prevents unauthorized access to hash list" do
      visit hash_list_path(other_hash_list)

      expect(page).to have_css("h1, h4", text: /Not Authorized/i)
    end
  end
end
