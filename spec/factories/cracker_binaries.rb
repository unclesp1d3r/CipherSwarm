# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: cracker_binaries
#
#  id                                                                :bigint           not null, primary key
#  active(Is the cracker binary active?)                             :boolean          default(TRUE), not null
#  major_version(The major version of the cracker binary.)           :integer
#  minor_version(The minor version of the cracker binary.)           :integer
#  patch_version(The patch version of the cracker binary.)           :integer
#  prerelease_version(The prerelease version of the cracker binary.) :string           default("")
#  version(Version of the cracker binary, e.g. 6.0.0 or 6.0.0-rc1)   :string           not null, indexed
#  created_at                                                        :datetime         not null
#  updated_at                                                        :datetime         not null
#
# Indexes
#
#  index_cracker_binaries_on_version  (version)
#
FactoryBot.define do
  factory :cracker_binary do
    active { true }
    version { Faker::App.semantic_version }
    operating_systems do
      [create(:operating_system, name: "Darwin"), create(:operating_system, name: "Windows")]
    end

    after(:build) do |cracker_binary|
      cracker_binary.archive_file.attach(
        io: Rails.root.join("spec/fixtures/cracker_binaries/hashcat.7z").open,
        filename: "hashcat-6.0.0.tar.gz", content_type: "application/x-7z-compressed"
      )
    end
  end
end
