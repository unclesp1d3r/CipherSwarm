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

  it_behaves_like "attack resource creation", :mask_list, "Mask list"
end
