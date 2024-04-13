# frozen_string_literal: true

# rubocop:disable RSpec/NamedSubject
require "rails_helper"

RSpec.describe "Routing ClientController" do
  it {
    expect(subject).to route(:get, "/api/v1/client/authenticate")
                         .to(format: :json, controller: "api/v1/client", action: :authenticate)
  }

  it {
    expect(subject).to route(:get, "/api/v1/client/configuration")
                         .to(format: :json, controller: "api/v1/client", action: :configuration)
  }
end
