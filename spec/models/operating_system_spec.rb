# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: operating_systems
#
#  id                                                     :bigint           not null, primary key
#  cracker_command(Command to run the cracker on this OS) :string           not null
#  name(Name of the operating system)                     :string           not null, indexed
#  created_at                                             :datetime         not null
#  updated_at                                             :datetime         not null
#
# Indexes
#
#  index_operating_systems_on_name  (name) UNIQUE
#
require "rails_helper"

RSpec.describe OperatingSystem do
  describe "validations" do
    subject { build(:operating_system) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:cracker_command) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:cracker_command).is_at_most(255) }
    it { is_expected.not_to allow_value("cracker command").for(:cracker_command) }
    it { is_expected.to allow_value("cracker_command").for(:cracker_command) }
  end
end
