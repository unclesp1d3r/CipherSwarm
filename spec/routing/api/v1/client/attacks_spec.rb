# rubocop:disable Rspec/NamedSubject
require 'rails_helper'

RSpec.describe 'Routing API AttacksController' do
  it { expect(subject).to route(:get, '/api/v1/client/attacks/1').
    to(format: :json, controller: 'api/v1/client/attacks', action: :show, id: 1) }

  it { expect(subject).to route(:get, '/api/v1/client/attacks/1/hash_list').
    to(format: :json, controller: 'api/v1/client/attacks', action: :hash_list, id: 1) }
end
