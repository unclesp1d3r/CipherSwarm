# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

# rubocop:disable RSpec/DescribeClass
RSpec.describe "AddCachedMetricsToAgents migration" do
  describe "agents columns" do
    describe "current_hash_rate column" do
      it "exists with correct type" do
        expect(ActiveRecord::Base.connection.column_exists?(:agents, :current_hash_rate, :decimal)).to be true
      end

      it "has correct precision and scale" do
        column = ActiveRecord::Base.connection.columns(:agents).find { |c| c.name == "current_hash_rate" }
        expect(column).not_to be_nil
        expect(column.precision).to eq(20)
        expect(column.scale).to eq(2)
      end

      it "has default value of 0" do
        column = ActiveRecord::Base.connection.columns(:agents).find { |c| c.name == "current_hash_rate" }
        expect(column.default).to eq("0.0").or eq("0")
      end
    end

    describe "current_temperature column" do
      it "exists with correct type" do
        expect(ActiveRecord::Base.connection.column_exists?(:agents, :current_temperature, :integer)).to be true
      end

      it "has default value of 0" do
        column = ActiveRecord::Base.connection.columns(:agents).find { |c| c.name == "current_temperature" }
        expect(column.default).to eq("0")
      end
    end

    describe "current_utilization column" do
      it "exists with correct type" do
        expect(ActiveRecord::Base.connection.column_exists?(:agents, :current_utilization, :integer)).to be true
      end

      it "has default value of 0" do
        column = ActiveRecord::Base.connection.columns(:agents).find { |c| c.name == "current_utilization" }
        expect(column.default).to eq("0")
      end
    end

    describe "metrics_updated_at column" do
      it "exists with correct type" do
        expect(ActiveRecord::Base.connection.column_exists?(:agents, :metrics_updated_at, :datetime)).to be true
      end
    end
  end

  describe "agents indexes" do
    it "has an index on metrics_updated_at" do
      expect(ActiveRecord::Base.connection.index_exists?(:agents, :metrics_updated_at)).to be true
    end

    it "has the correctly named index" do
      index = ActiveRecord::Base.connection.indexes(:agents).find { |i| i.columns == ["metrics_updated_at"] }
      expect(index).not_to be_nil
      expect(index.name).to eq("index_agents_on_metrics_updated_at")
    end
  end
end
# rubocop:enable RSpec/DescribeClass
