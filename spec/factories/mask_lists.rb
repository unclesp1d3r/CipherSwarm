# frozen_string_literal: true

# == Schema Information
#
# Table name: mask_lists
#
#  id                                           :bigint           not null, primary key
#  description(Description of the mask list)    :text
#  line_count(Number of lines in the mask list) :bigint
#  name(Name of the mask list)                  :string(255)      not null, indexed
#  processed(Has the mask list been processed?) :boolean          default(FALSE), not null, indexed
#  sensitive(Is the mask list sensitive?)       :boolean          default(FALSE), not null
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#
# Indexes
#
#  index_mask_lists_on_name       (name) UNIQUE
#  index_mask_lists_on_processed  (processed)
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