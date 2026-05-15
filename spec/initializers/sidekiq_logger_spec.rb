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

  describe "config/initializers/sidekiq.rb wires the JSON formatter on the server" do
    # `Sidekiq.configure_server` is a no-op in the test environment because
    # `Sidekiq::CLI` is not loaded — meaning a naive spec that creates its own
    # logger would pass even if the initializer file were deleted. Capture the
    # configure_server block, run it against a real Sidekiq config object, and
    # assert the wiring directly.
    let(:captured_config) { Sidekiq::Config.new }

    it "sets the server logger to JSON output on $stdout" do
      allow(Sidekiq).to receive(:configure_server).and_yield(captured_config)
      load Rails.root.join("config/initializers/sidekiq.rb").to_s

      expect(captured_config.logger).to be_a(Sidekiq::Logger)
      expect(captured_config.logger.formatter).to be_a(Sidekiq::Logger::Formatters::JSON)
      expect(captured_config.logger.level).to eq(Logger::INFO)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
