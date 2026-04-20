# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe SoftDeletable do
  describe ".discards_with_counter_cache" do
    it "raises ArgumentError when the association does not exist" do
      model = Class.new(ApplicationRecord) do
        self.table_name = "attacks"
        include SoftDeletable
      end
      expect { model.discards_with_counter_cache :attacks_count, on: :nonexistent }
        .to raise_error(ArgumentError, /no association `nonexistent`/)
    end

    it "raises ArgumentError when the association is not a belongs_to" do
      model = Class.new(ApplicationRecord) do
        self.table_name = "campaigns"
        include SoftDeletable
        has_many :attacks # not belongs_to
      end
      expect { model.discards_with_counter_cache :attacks_count, on: :attacks }
        .to raise_error(ArgumentError, /not a belongs_to \(got has_many\)/)
    end
  end

  describe "model inclusion" do
    it "is included in Campaign" do
      expect(Campaign.included_modules).to include(described_class)
    end

    it "is included in Attack" do
      expect(Attack.included_modules).to include(described_class)
    end
  end
end
