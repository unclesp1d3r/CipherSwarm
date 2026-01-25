# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"
require "support/migration_helper"
require_relative "../../../db/migrate/20260112051934_simplify_campaign_priorities"

RSpec.describe SimplifyCampaignPriorities, type: :migration do
  include MigrationHelper
  let(:connection) { ActiveRecord::Base.connection }
  let(:hash_type) { HashType.find_by(hashcat_mode: 0) || create(:md5) }
  let(:project) { create(:project) }
  let(:hash_list) { create(:hash_list, hash_type: hash_type, project: project) }

  ##
  # Set a campaign's priority value directly in the database and reload the campaign instance.
  # @param [Campaign] campaign - The campaign record to update.
  # @param [Integer] priority_value - The priority value to write to the database (e.g., -1, 0, 1, 2, 3, 4, 5).
  # @return [Campaign] The reloaded campaign reflecting the updated priority.
  def set_campaign_priority(campaign, priority_value)
    connection.execute("UPDATE campaigns SET priority = #{priority_value} WHERE id = #{campaign.id}")
    campaign.reload
  end

  ##
  # Retrieves the raw priority value for the given campaign directly from the database.
  # @param [Campaign] campaign - The campaign whose priority to fetch.
  # @return [Integer, nil] The priority value stored in the database for that campaign, or `nil` if no record exists.
  def get_campaign_priority(campaign)
    connection.select_value("SELECT priority FROM campaigns WHERE id = #{campaign.id}")
  end

  describe "#up" do
    context "when migrating flash_override (5) campaigns" do
      it "converts to high (2)" do
        campaign = create(:campaign, hash_list: hash_list, project: project)
        set_campaign_priority(campaign, 5)

        # Verify priority is set correctly before migration
        expect(get_campaign_priority(campaign)).to eq(5)

        migrate_up(described_class.new)

        expect(get_campaign_priority(campaign)).to eq(2)
      end
    end

    context "when migrating flash (4) campaigns" do
      it "converts to high (2)" do
        campaign = create(:campaign, hash_list: hash_list, project: project)
        set_campaign_priority(campaign, 4)

        # Verify priority is set correctly before migration
        expect(get_campaign_priority(campaign)).to eq(4)

        migrate_up(described_class.new)

        expect(get_campaign_priority(campaign)).to eq(2)
      end
    end

    context "when migrating immediate (3) campaigns" do
      it "converts to high (2)" do
        campaign = create(:campaign, hash_list: hash_list, project: project)
        set_campaign_priority(campaign, 3)

        # Verify priority is set correctly before migration
        expect(get_campaign_priority(campaign)).to eq(3)

        migrate_up(described_class.new)

        expect(get_campaign_priority(campaign)).to eq(2)
      end
    end

    context "when migrating urgent (2) campaigns" do
      it "converts to normal (0)" do
        campaign = create(:campaign, hash_list: hash_list, project: project)
        set_campaign_priority(campaign, 2)

        migrate_up(described_class.new)

        expect(get_campaign_priority(campaign)).to eq(0)
      end
    end

    context "when migrating priority (1) campaigns" do
      it "converts to normal (0)" do
        campaign = create(:campaign, hash_list: hash_list, project: project)
        set_campaign_priority(campaign, 1)

        migrate_up(described_class.new)

        expect(get_campaign_priority(campaign)).to eq(0)
      end
    end

    context "when migrating routine (0) campaigns" do
      it "remains normal (0)" do
        campaign = create(:campaign, hash_list: hash_list, project: project, priority: :normal)

        migrate_up(described_class.new)

        expect(get_campaign_priority(campaign)).to eq(0)
      end
    end

    context "when migrating deferred (-1) campaigns" do
      it "remains deferred (-1)" do
        campaign = create(:campaign, hash_list: hash_list, project: project, priority: :deferred)

        migrate_up(described_class.new)

        expect(get_campaign_priority(campaign)).to eq(-1)
      end
    end
  end

  describe "#down" do
    context "when reverting high (2) campaigns" do
      it "converts to normal (0) as safe fallback" do
        campaign = create(:campaign, hash_list: hash_list, project: project, priority: :high)

        migrate_down(described_class.new)

        expect(get_campaign_priority(campaign)).to eq(0)
      end
    end

    context "when reverting normal (0) campaigns" do
      it "remains normal (0)" do
        campaign = create(:campaign, hash_list: hash_list, project: project, priority: :normal)

        migrate_down(described_class.new)

        expect(get_campaign_priority(campaign)).to eq(0)
      end
    end

    context "when reverting deferred (-1) campaigns" do
      it "remains deferred (-1)" do
        campaign = create(:campaign, hash_list: hash_list, project: project, priority: :deferred)

        migrate_down(described_class.new)

        expect(get_campaign_priority(campaign)).to eq(-1)
      end
    end
  end
end
