# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

# rubocop:disable RSpec/DescribeClass -- tests an initializer, not a class
RSpec.describe "filter_parameters configuration" do
  # Rails normalises `filter_parameters` to either a symbol/string list or a
  # compiled Regexp depending on app boot order, so assert behavior through a
  # live `ActiveSupport::ParameterFilter` rather than introspecting structure.
  let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

  credential_keys = %w[passw email secret token _key crypt salt certificate otp ssn cvv cvc].freeze
  hash_keys = %w[hash_value plain_text].freeze

  credential_keys.each do |key|
    it "redacts credential-like key #{key.inspect}" do
      result = filter.filter(key => "sensitive-value-#{key}")
      expect(result[key]).to eq("[FILTERED]"), "expected #{key.inspect} to be redacted by filter_parameters"
    end
  end

  hash_keys.each do |key|
    it "redacts hash submission key #{key.inspect}" do
      result = filter.filter(key => "5f4dcc3b5aa765d61d8327deb882cf99")
      expect(result[key]).to eq("[FILTERED]"), "expected #{key.inspect} to be redacted across all Agent API versions"
    end
  end

  it "leaves non-sensitive keys untouched" do
    result = filter.filter("task_id" => 42, "name" => "alice")
    expect(result["task_id"]).to eq(42)
    expect(result["name"]).to eq("alice")
  end

  describe "v1 Agent API `hash` wire-key redaction" do
    # The v1 submit_crack endpoint at app/controllers/api/v1/client/tasks_controller.rb
    # reads `params[:hash]`. Substring matching against `:hash_value` does NOT match
    # the literal key `hash`, so it would leak the raw cracked-hash payload through
    # any params-dumping path (Rails exception page, Sidekiq retry serialization,
    # NewRelic/AppSignal, etc.). The anchored regex `/\Ahash\z/i` redacts only
    # the exact key.
    it "redacts the exact `hash` wire key" do
      result = filter.filter("hash" => "5f4dcc3b5aa765d61d8327deb882cf99")
      expect(result["hash"]).to eq("[FILTERED]")
    end

    it "redacts a symbolised `:hash` wire key" do
      result = filter.filter(hash: "5f4dcc3b5aa765d61d8327deb882cf99")
      expect(result[:hash]).to eq("[FILTERED]")
    end

    it "does NOT redact unrelated `hash`-prefixed keys" do
      # These are non-secret references — redacting them would lose useful debug
      # context. The anchored regex must not match.
      result = filter.filter(
        "hash_list_id" => 7,
        "hash_type" => "MD5",
        "hashed_password" => "not-a-secret-id",
        "password_hash" => "another-ref"
      )
      expect(result["hash_list_id"]).to eq(7)
      expect(result["hash_type"]).to eq("MD5")
      # password_hash and hashed_password contain the substring "passw" so they
      # match the existing credential filter, not the new `hash` filter.
      expect(result["hashed_password"]).to eq("[FILTERED]")
      expect(result["password_hash"]).to eq("[FILTERED]")
    end
  end
end
# rubocop:enable RSpec/DescribeClass
