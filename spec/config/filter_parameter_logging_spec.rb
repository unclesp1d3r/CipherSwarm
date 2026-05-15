# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

# rubocop:disable RSpec/DescribeClass -- tests an initializer, not a class
RSpec.describe "filter_parameters configuration" do
  let(:filtered) { Rails.application.config.filter_parameters.map(&:to_s) }

  it "filters credentials and secrets" do
    %w[passw email secret token _key crypt salt certificate otp ssn cvv cvc].each do |key|
      expect(filtered).to include(key), "expected filter_parameters to include #{key.inspect}"
    end
  end

  it "filters hash submission fields used across Agent API v1 and v2" do
    expect(filtered).to include("hash_value", "plain_text")
  end

  it "redacts hash_value and plain_text from a real ParameterFilter" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered_params = filter.filter(
      "hash_value" => "5f4dcc3b5aa765d61d8327deb882cf99",
      "plain_text" => "hunter2",
      "task_id" => 42
    )
    expect(filtered_params["hash_value"]).to eq("[FILTERED]")
    expect(filtered_params["plain_text"]).to eq("[FILTERED]")
    expect(filtered_params["task_id"]).to eq(42)
  end
end
# rubocop:enable RSpec/DescribeClass
