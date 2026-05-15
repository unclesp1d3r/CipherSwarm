# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

require "rails_helper"

# rubocop:disable RSpec/DescribeClass -- tests an initializer, not a class
RSpec.describe "Lograge configuration" do
  let(:custom_options) { Rails.application.config.lograge.custom_options }
  # NOTE: lograge stores the custom_payload block on `custom_payload_method`, not
  # `custom_payload` (which is a writer that takes a block — see
  # `Lograge::OrderedOptions#custom_payload`). Reading it back requires the
  # `_method` accessor.
  let(:custom_payload) { Rails.application.config.lograge.custom_payload_method }

  describe "custom_options" do
    let(:base_payload) do
      {
        host: "cipherswarm.lab.local",
        request_id: "req-abc",
        user_agent: "curl/8",
        ip: "10.0.0.5"
      }
    end
    let(:event) do
      instance_double(ActiveSupport::Notifications::Event, payload: base_payload)
    end

    it "returns host, request_id, user_agent, ip and an iso8601 time" do
      result = custom_options.call(event)
      expect(result).to include(
        host: "cipherswarm.lab.local",
        request_id: "req-abc",
        user_agent: "curl/8",
        ip: "10.0.0.5"
      )
      expect(result[:time]).to match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it "includes agent_id, task_id, attack_id, user_id when present" do
      allow(event).to receive(:payload).and_return(
        base_payload.merge(agent_id: 7, task_id: 42, attack_id: 11, user_id: 3)
      )
      result = custom_options.call(event)
      expect(result).to include(agent_id: 7, task_id: 42, attack_id: 11, user_id: 3)
    end

    it "omits domain ids when absent" do
      result = custom_options.call(event)
      expect(result).not_to have_key(:agent_id)
      expect(result).not_to have_key(:task_id)
      expect(result).not_to have_key(:attack_id)
      expect(result).not_to have_key(:user_id)
    end

    it "includes exception class and message when payload has :exception" do
      allow(event).to receive(:payload).and_return(
        base_payload.merge(exception: ["StandardError", "boom"])
      )
      result = custom_options.call(event)
      expect(result[:exception_class]).to eq("StandardError")
      expect(result[:exception_message]).to eq("boom")
    end

    it "truncates backtrace to first 5 frames when exception_object is present" do
      exc = StandardError.new("boom")
      exc.set_backtrace((1..20).map { |i| "frame_#{i}" })
      allow(event).to receive(:payload).and_return(
        base_payload.merge(exception: ["StandardError", "boom"], exception_object: exc)
      )
      result = custom_options.call(event)
      expect(result[:backtrace]).to eq(%w[frame_1 frame_2 frame_3 frame_4 frame_5])
    end

    context "with hostile exception data (log-injection defense)" do
      it "strips newlines and carriage returns from exception_message" do
        allow(event).to receive(:payload).and_return(
          base_payload.merge(exception: ["StandardError", "line1\nline2\rline3"])
        )
        result = custom_options.call(event)
        expect(result[:exception_message]).not_to include("\n")
        expect(result[:exception_message]).not_to include("\r")
      end

      it "truncates exception_message longer than 500 chars" do
        allow(event).to receive(:payload).and_return(
          base_payload.merge(exception: ["StandardError", "x" * 1000])
        )
        result = custom_options.call(event)
        expect(result[:exception_message].length).to be <= 500
      end

      it "coerces exception_class to a String even if it arrives as a Class" do
        allow(event).to receive(:payload).and_return(
          base_payload.merge(exception: [StandardError, "boom"])
        )
        result = custom_options.call(event)
        expect(result[:exception_class]).to eq("StandardError")
      end
    end
  end

  describe "custom_payload extraction" do
    let(:controller_class) do
      Class.new do
        attr_accessor :params, :request, :controller_name

        def initialize(request:, params:, controller_name:)
          @request = request
          @params = params
          @controller_name = controller_name
        end
      end
    end

    let(:request_double) do
      instance_double(
        ActionDispatch::Request,
        host: "h",
        request_id: "r",
        user_agent: "ua",
        remote_ip: "1.2.3.4"
      )
    end

    def build_controller(params:, controller_name: "anything")
      controller_class.new(request: request_double, params: params, controller_name: controller_name)
    end

    it "extracts task_id from params[:id] when controller is tasks" do
      payload = custom_payload.call(build_controller(params: { id: "99" }, controller_name: "tasks"))
      expect(payload[:task_id]).to eq("99")
    end

    it "extracts attack_id from params[:id] when controller is attacks" do
      payload = custom_payload.call(build_controller(params: { id: "55" }, controller_name: "attacks"))
      expect(payload[:attack_id]).to eq("55")
    end

    it "extracts agent_id from params[:agent_id] when no current_agent and no @agent" do
      payload = custom_payload.call(build_controller(params: { agent_id: "7" }))
      expect(payload[:agent_id]).to eq("7")
    end

    it "extracts task_id from params[:task_id] when controller is not tasks" do
      payload = custom_payload.call(build_controller(params: { task_id: "123" }))
      expect(payload[:task_id]).to eq("123")
    end

    it "always includes host, request_id, user_agent, ip" do
      payload = custom_payload.call(build_controller(params: {}))
      expect(payload).to include(host: "h", request_id: "r", user_agent: "ua", ip: "1.2.3.4")
    end

    it "does not set agent_id when no source is available (unauthenticated path)" do
      payload = custom_payload.call(build_controller(params: {}))
      expect(payload).not_to have_key(:agent_id)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
