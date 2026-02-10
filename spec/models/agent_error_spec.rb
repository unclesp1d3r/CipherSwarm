# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: agent_errors
#
#  id                                              :bigint           not null, primary key
#  message(The error message)                      :string           not null
#  metadata(Additional metadata about the error)   :jsonb            not null
#  severity(The severity of the error)             :integer          default("info"), not null
#  created_at                                      :datetime         not null, indexed
#  updated_at                                      :datetime         not null
#  agent_id(The agent that caused the error)       :bigint           not null, indexed
#  task_id(The task that caused the error, if any) :bigint           indexed
#
# Indexes
#
#  index_agent_errors_on_agent_id    (agent_id)
#  index_agent_errors_on_created_at  (created_at)
#  index_agent_errors_on_task_id     (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id)
#  fk_rails_...  (task_id => tasks.id)
#
require "rails_helper"

RSpec.describe AgentError do
  include ActiveSupport::Testing::TimeHelpers

  describe "validations" do
    it { is_expected.to validate_presence_of(:message) }
    it { is_expected.to validate_presence_of(:metadata) }
    it { is_expected.to validate_presence_of(:severity) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:agent) }
    it { is_expected.to belong_to(:task).optional }
  end

  describe "columns" do
    it { is_expected.to have_db_column(:message).of_type(:string).with_options(null: false) }
    it { is_expected.to have_db_column(:metadata).of_type(:jsonb).with_options(null: false) }
    it { is_expected.to have_db_column(:severity).of_type(:integer).with_options(null: false) }
  end

  describe ".remove_old_errors" do
    let(:agent) { create(:agent) }

    it "deletes errors older than the retention period" do
      old_error = travel_to(31.days.ago) { create(:agent_error, agent: agent) }
      recent_error = travel_to(29.days.ago) { create(:agent_error, agent: agent) }

      expect { described_class.remove_old_errors }.to change(described_class, :count).by(-1)
      expect(described_class.unscoped.exists?(old_error.id)).to be false
      expect(described_class.unscoped.exists?(recent_error.id)).to be true
    end

    it "preserves errors within the retention period" do
      travel_to(1.day.ago) { create(:agent_error, agent: agent) }

      expect { described_class.remove_old_errors }.not_to change(described_class, :count)
    end

    it "returns the count of deleted records" do
      travel_to(31.days.ago) { 3.times { create(:agent_error, agent: agent) } }

      expect(described_class.remove_old_errors).to eq(3)
    end

    it "returns zero when no records to delete" do
      expect(described_class.remove_old_errors).to eq(0)
    end
  end
end
