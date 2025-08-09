# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# rubocop:disable RSpec/NamedSubject
require "rails_helper"

RSpec.describe "Routing API CrackersController" do
  it {
    expect(subject).to route(:get, "/api/v1/client/tasks/1")
                         .to(format: :json, controller: "api/v1/client/tasks", action: :show, id: 1)
  }

  it {
    expect(subject).to route(:get, "/api/v1/client/tasks/new")
                         .to(format: :json, controller: "api/v1/client/tasks", action: :new)
  }

  it {
    expect(subject).to route(:put, "/api/v1/client/tasks/1")
                         .to(format: :json, controller: "api/v1/client/tasks", action: :update, id: 1)
  }

  it {
    expect(subject).to route(:patch, "/api/v1/client/tasks/1")
                         .to(format: :json, controller: "api/v1/client/tasks", action: :update, id: 1)
  }

  it {
    expect(subject).to route(:post, "/api/v1/client/tasks/1/submit_crack")
                         .to(format: :json, controller: "api/v1/client/tasks", action: :submit_crack, id: 1)
  }

  it {
    expect(subject).to route(:post, "/api/v1/client/tasks/1/submit_status")
                         .to(format: :json, controller: "api/v1/client/tasks", action: :submit_status, id: 1)
  }

  it {
    expect(subject).to route(:post, "/api/v1/client/tasks/1/accept_task")
                         .to(format: :json, controller: "api/v1/client/tasks", action: :accept_task, id: 1)
  }

  it {
    expect(subject).to route(:post, "/api/v1/client/tasks/1/exhausted")
                         .to(format: :json, controller: "api/v1/client/tasks", action: :exhausted, id: 1)
  }

  it {
    expect(subject).to route(:post, "/api/v1/client/tasks/1/abandon")
                         .to(format: :json, controller: "api/v1/client/tasks", action: :abandon, id: 1)
  }
end
