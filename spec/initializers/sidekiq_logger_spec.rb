# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"
require "stringio"

# rubocop:disable RSpec/DescribeClass -- tests an initializer, not a class
RSpec.describe "Sidekiq logger configuration" do
  it "exposes a JSON formatter on Sidekiq" do
    expect(defined?(Sidekiq::Logger::Formatters::JSON)).to eq("constant")
  end

  it "writes parseable single-line JSON when invoked" do
    formatter = Sidekiq::Logger::Formatters::JSON.new
    io = StringIO.new
    logger = Sidekiq::Logger.new(io)
    logger.formatter = formatter
    logger.info("hello world")

    output = io.string
    expect(output).to end_with("\n")
    expect(output.count("\n")).to eq(1)

    parsed = JSON.parse(output.strip)
    expect(parsed).to include("msg" => "hello world", "lvl" => "INFO")
    expect(parsed).to have_key("ts")
    expect(parsed).to have_key("pid")
  end
end
# rubocop:enable RSpec/DescribeClass
