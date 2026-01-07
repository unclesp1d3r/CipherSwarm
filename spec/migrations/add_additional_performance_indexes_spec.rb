# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "AddAdditionalPerformanceIndexes migration" do
  describe "hash_items indexes" do
    it "has an index on cracked_time" do
      expect(ActiveRecord::Base.connection.index_exists?(:hash_items, :cracked_time)).to be true
    end

    it "has the correctly named index" do
      index = ActiveRecord::Base.connection.indexes(:hash_items).find { |i| i.columns == ["cracked_time"] }
      expect(index).not_to be_nil
      expect(index.name).to eq("index_hash_items_on_cracked_time")
    end
  end

  describe "agent_errors indexes" do
    it "has an index on created_at" do
      expect(ActiveRecord::Base.connection.index_exists?(:agent_errors, :created_at)).to be true
    end

    it "has the correctly named index" do
      index = ActiveRecord::Base.connection.indexes(:agent_errors).find { |i| i.columns == ["created_at"] }
      expect(index).not_to be_nil
      expect(index.name).to eq("index_agent_errors_on_created_at")
    end
  end

  describe "hashcat_statuses indexes" do
    it "has an index on time" do
      expect(ActiveRecord::Base.connection.index_exists?(:hashcat_statuses, :time)).to be true
    end

    it "has the correctly named index" do
      index = ActiveRecord::Base.connection.indexes(:hashcat_statuses).find { |i| i.columns == ["time"] }
      expect(index).not_to be_nil
      expect(index.name).to eq("index_hashcat_statuses_on_time")
    end
  end

  describe "tasks indexes" do
    it "has a composite index on agent_id and state" do
      expect(ActiveRecord::Base.connection.index_exists?(:tasks, %i[agent_id state])).to be true
    end

    it "has the correctly named composite index" do
      index = ActiveRecord::Base.connection.indexes(:tasks).find { |i| i.columns == %w[agent_id state] }
      expect(index).not_to be_nil
      expect(index.name).to eq("index_tasks_on_agent_id_and_state")
    end
  end
end
# rubocop:enable RSpec/DescribeClass
