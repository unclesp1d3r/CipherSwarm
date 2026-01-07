# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: agents
#
#  id                                                                                     :bigint           not null, primary key
#  advanced_configuration(Advanced configuration for the agent.)                          :jsonb
#  client_signature(The signature of the agent)                                           :text
#  current_hash_rate(Current hash rate in H/s, updated from HashcatStatus)                :decimal(20, 2)   default(0.0)
#  current_temperature(Current device temperature in Celsius, updated from HashcatStatus) :integer          default(0)
#  current_utilization(Current device utilization percentage, updated from HashcatStatus) :integer          default(0)
#  custom_label(Custom label for the agent)                                               :string           uniquely indexed
#  devices(Devices that the agent supports)                                               :string           default([]), is an Array
#  enabled(Is the agent active)                                                           :boolean          default(TRUE), not null
#  host_name(Name of the agent)                                                           :string           default(""), not null
#  last_ipaddress(Last known IP address)                                                  :string           default("")
#  last_seen_at(Last time the agent checked in)                                           :datetime         indexed => [state]
#  metrics_updated_at(Timestamp of last metrics update for throttling)                    :datetime         indexed
#  operating_system(Operating system of the agent)                                        :integer          default("unknown")
#  state(The state of the agent)                                                          :string           default("pending"), not null, indexed, indexed => [last_seen_at]
#  token(Token used to authenticate the agent)                                            :string(24)       uniquely indexed
#  created_at                                                                             :datetime         not null
#  updated_at                                                                             :datetime         not null
#  user_id(The user that the agent is associated with)                                    :bigint           not null, indexed
#
# Indexes
#
#  index_agents_on_custom_label            (custom_label) UNIQUE
#  index_agents_on_metrics_updated_at      (metrics_updated_at)
#  index_agents_on_state                   (state)
#  index_agents_on_state_and_last_seen_at  (state,last_seen_at)
#  index_agents_on_token                   (token) UNIQUE
#  index_agents_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe Agent do
  describe "validations" do
    subject { build(:agent) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:host_name) }
    it { is_expected.to validate_length_of(:host_name).is_at_most(255) }
    it { is_expected.to validate_length_of(:custom_label).is_at_most(255) }
    it { is_expected.to validate_uniqueness_of(:token) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:tasks) }
    it { is_expected.to have_and_belong_to_many(:projects) }
    it { is_expected.to have_many(:hashcat_benchmarks) }
  end

  describe "columns" do
    it { is_expected.to have_db_column(:enabled).of_type(:boolean).with_options(default: true) }
    it { is_expected.to define_enum_for(:operating_system) }
    it { is_expected.to have_db_column(:devices).of_type(:string).with_options(default: []) }
    it { is_expected.to have_readonly_attribute(:token) }
  end

  describe "methods" do
    let(:agent) { create(:agent) }
    let(:task) { create(:task, agent: agent) }

    it "has a valid token" do
      expect(agent.token).to be_truthy
      expect(agent.token).to be_a(String)
      expect(agent.token.length).to eq(24)
    end

    it "has a unique token" do
      agent2 = create(:agent, id: 2, user: agent.user)

      expect(agent.token).to be_truthy
      expect(agent2.token).to be_truthy
      expect(agent.token).not_to eq(agent2.token)
    end

    it "returns custom_label if set, otherwise host_name" do
      agent.custom_label = "Custom Label"
      expect(agent.name).to eq("Custom Label")

      agent.custom_label = nil
      expect(agent.name).to eq(agent.host_name)
    end

    describe "#meets_performance_threshold?" do
      let(:hash_type) { 1000 }

      before do
        create(:hashcat_benchmark, agent: agent, hash_type: hash_type, hash_speed: 2000)
        allow(ApplicationConfig).to receive(:min_performance_benchmark).and_return(1000)
      end

      it "returns true if the agent meets the minimum performance benchmark" do
        expect(agent.meets_performance_threshold?(hash_type)).to be true
      end

      it "returns false if the agent does not meet the minimum performance benchmark" do
        allow(ApplicationConfig).to receive(:min_performance_benchmark).and_return(3000)
        expect(agent.meets_performance_threshold?(hash_type)).to be false
      end
    end

    describe "#hash_rate_display" do
      let(:agent) { create(:agent) }

      it "returns '—' when current_hash_rate is nil" do
        agent.current_hash_rate = nil
        expect(agent.hash_rate_display).to eq("—")
      end

      it "returns '0 H/s' when current_hash_rate is zero" do
        agent.current_hash_rate = 0
        expect(agent.hash_rate_display).to eq("0 H/s")
      end

      it "returns formatted hash rate with SI prefix for positive values" do
        agent.current_hash_rate = 123_450_000_000 # 123.45 GH/s
        display = agent.hash_rate_display
        expect(display).to include("H/s")
        expect(display).not_to be_empty
      end

      it "returns formatted hash rate for small values" do
        agent.current_hash_rate = 1000 # 1 KH/s
        display = agent.hash_rate_display
        expect(display).to include("H/s")
      end
    end
  end

  describe "scopes" do
    let(:agent) { create(:agent) }
    let(:agent2) { create(:agent, state: "offline") }

    it "returns active agents" do
      expect(described_class.active).to include(agent)
    end

    it "does not return inactive agents" do
      expect(described_class.active).not_to include(agent2)
    end
  end

  describe "callbacks" do
    let(:agent) { create(:agent) }

    it "creates a client signature" do
      expect(agent.client_signature).to be_truthy
    end
  end
end
