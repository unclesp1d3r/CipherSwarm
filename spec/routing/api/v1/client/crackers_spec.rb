# frozen_string_literal: true

# rubocop:disable RSpec/NamedSubject
require "rails_helper"

RSpec.describe "Routing API CrackersController" do
  it {
    expect(subject).to route(:get, "/api/v1/client/crackers/check_for_cracker_update")
                         .to(format: :json, controller: "api/v1/client/crackers", action: :check_for_cracker_update)
  }
end
