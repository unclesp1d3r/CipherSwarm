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
end
# rubocop:enable RSpec/DescribeClass
