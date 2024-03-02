# == Schema Information
#
# Table name: agents
#
#  id                                                                         :bigint           not null, primary key
#  active(Is the agent active)                                                :boolean          default(TRUE)
#  client_signature(The signature of the agent)                               :text
#  command_parameters(Parameters to be passed to the agent when it checks in) :text
#  cpu_only(Only use for CPU only tasks)                                      :boolean          default(FALSE)
#  devices(Devices that the agent supports)                                   :string           default([]), is an Array
#  ignore_errors(Ignore errors, continue to next task)                        :boolean          default(FALSE)
#  last_ipaddress(Last known IP address)                                      :string           default("")
#  last_seen_at(Last time the agent checked in)                               :datetime
#  name(Name of the agent)                                                    :string           default("")
#  operating_system(Operating system of the agent)                            :integer          default("unknown")
#  token(Token used to authenticate the agent)                                :string(24)       indexed
#  trusted(Is the agent trusted to handle sensitive data)                     :boolean          default(FALSE)
#  created_at                                                                 :datetime         not null
#  updated_at                                                                 :datetime         not null
#  user_id(The user that the agent is associated with)                        :bigint           indexed
#
# Indexes
#
#  index_agents_on_token    (token) UNIQUE
#  index_agents_on_user_id  (user_id)
#
require 'rails_helper'

RSpec.describe Agent, type: :model do
  it "is valid with valid attributes" do
    user = create(:user)
    agent = create(:agent)

    expect(agent).to be_valid
  end

  it "is not valid without a name" do
    agent = build(:agent, name: nil)

    expect(agent).to_not be_valid
  end

  it "has a valid token" do
    user = create(:user)
    agent = create(:agent)

    expect(agent.token).to be_truthy
    expect(agent.token).to be_a(String)
    expect(agent.token.length).to eq(24)
  end

  it "has a unique token" do
    user = create(:user)
    agent = create(:agent)
    agent2 = create(:agent, id: 2, user_id: user.id)

    expect(agent.token).to be_truthy
    expect(agent2.token).to be_truthy
    expect(agent.token).to_not eq(agent2.token)
  end

  it "has a default active value of true" do
    user = create(:user)
    agent = create(:agent)

    expect(agent.active).to be_truthy
  end
end
