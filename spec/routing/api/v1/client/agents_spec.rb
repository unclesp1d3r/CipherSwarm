# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# rubocop:disable RSpec/NamedSubject
require "rails_helper"

RSpec.describe "Routing API AgentsController" do
  describe "Agents" do
    it {
      expect(subject).to route(:get, "/api/v1/client/agents/1")
                           .to(format: :json, controller: "api/v1/client/agents", action: :show, id: 1)
    }

    it {
      expect(subject).to route(:put, "/api/v1/client/agents/1")
                           .to(format: :json, controller: "api/v1/client/agents", action: :update, id: 1)
    }

    it {
      expect(subject).to route(:post, "/api/v1/client/agents/1/submit_benchmark")
                           .to(format: :json, controller: "api/v1/client/agents", action: :submit_benchmark, id: 1)
    }

    it {
      expect(subject).to route(:post, "/api/v1/client/agents/1/heartbeat")
                           .to(format: :json, controller: "api/v1/client/agents", action: :heartbeat, id: 1)
    }

    it {
      expect(subject).to route(:post, "/api/v1/client/agents/1/shutdown")
                           .to(format: :json, controller: "api/v1/client/agents", action: :shutdown, id: 1)
    }
  end
end
