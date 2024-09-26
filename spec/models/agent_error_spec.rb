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
#  created_at                                      :datetime         not null
#  updated_at                                      :datetime         not null
#  agent_id(The agent that caused the error)       :bigint           not null, indexed
#  task_id(The task that caused the error, if any) :bigint           indexed
#
# Indexes
#
#  index_agent_errors_on_agent_id  (agent_id)
#  index_agent_errors_on_task_id   (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (agent_id => agents.id)
#  fk_rails_...  (task_id => tasks.id)
#
require "rails_helper"

RSpec.describe AgentError, type: :model do
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
end
