# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: mask_lists
#
#  id                                                  :bigint           not null, primary key
#  complexity_value(Total attemptable password values) :decimal(, )      default(0.0)
#  description(Description of the mask list)           :text
#  line_count(Number of lines in the mask list)        :bigint
#  name(Name of the mask list)                         :string(255)      not null, indexed
#  processed(Has the mask list been processed?)        :boolean          default(FALSE), not null, indexed
#  sensitive(Is the mask list sensitive?)              :boolean          default(FALSE), not null
#  created_at                                          :datetime         not null
#  updated_at                                          :datetime         not null
#  creator_id(The user who created this list)          :bigint           indexed
#
# Indexes
#
#  index_mask_lists_on_creator_id  (creator_id)
#  index_mask_lists_on_name        (name) UNIQUE
#  index_mask_lists_on_processed   (processed)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#
FactoryBot.define do
  factory :mask_list do
    name
    sensitive { false }
    description { Faker::Lorem.paragraph }
    projects { [Project.first || create(:project)] }

    after(:build) do |mask_list|
      mask_list.file.attach(
        io: Rails.root.join("spec/fixtures/mask_lists/rockyou-1-60.hcmask").open,
        filename: "rockyou-1-60.hcmask", content_type: "text/plain"
      )
    end
  end
end
