# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: agents
#
#  id                                                            :bigint           not null, primary key
#  advanced_configuration(Advanced configuration for the agent.) :jsonb
#  client_signature(The signature of the agent)                  :text
#  custom_label(Custom label for the agent)                      :string           indexed
#  devices(Devices that the agent supports)                      :string           default([]), is an Array
#  enabled(Is the agent active)                                  :boolean          default(TRUE), not null
#  host_name(Name of the agent)                                  :string           default(""), not null
#  last_ipaddress(Last known IP address)                         :string           default("")
#  last_seen_at(Last time the agent checked in)                  :datetime
#  operating_system(Operating system of the agent)               :integer          default("unknown")
#  state(The state of the agent)                                 :string           default("pending"), not null, indexed
#  token(Token used to authenticate the agent)                   :string(24)       indexed
#  created_at                                                    :datetime         not null
#  updated_at                                                    :datetime         not null
#  user_id(The user that the agent is associated with)           :bigint           not null, indexed
#
# Indexes
#
#  index_agents_on_custom_label  (custom_label) UNIQUE
#  index_agents_on_state         (state)
#  index_agents_on_token         (token) UNIQUE
#  index_agents_on_user_id       (user_id)
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
