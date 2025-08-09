# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# rubocop:disable RSpec/NamedSubject
require "rails_helper"

RSpec.describe "Routing API AttacksController" do
  it {
    expect(subject).to route(:get, "/api/v1/client/attacks/1")
                         .to(format: :json, controller: "api/v1/client/attacks", action: :show, id: 1)
  }

  it {
    expect(subject).to route(:get, "/api/v1/client/attacks/1/hash_list")
                         .to(format: :json, controller: "api/v1/client/attacks", action: :hash_list, id: 1)
  }
end
