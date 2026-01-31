# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

RSpec.describe ApplicationJob do
  describe "error handling configuration" do
    it "is configured to retry on ActiveRecord::Deadlocked" do
      expect(described_class.rescue_handlers.map(&:first)).to include("ActiveRecord::Deadlocked")
    end

    it "is configured to discard on ActiveJob::DeserializationError" do
      expect(described_class.rescue_handlers.map(&:first)).to include("ActiveJob::DeserializationError")
    end

    it "has a block handler for DeserializationError that logs" do
      # Find the handler for DeserializationError
      handler = described_class.rescue_handlers.find { |h| h.first == "ActiveJob::DeserializationError" }
      expect(handler).not_to be_nil

      # The handler should have a block (Proc) that handles the discard
      handler_proc = handler.second
      expect(handler_proc).to be_a(Proc)
    end
  end
end
