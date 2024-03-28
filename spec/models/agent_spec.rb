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
  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:user) }
  it { should have_db_column(:active).of_type(:boolean).with_options(default: true) }
  it { should have_db_column(:client_signature).of_type(:text) }
  it { should define_enum_for(:operating_system).with_values(unknown: 0, linux: 1, windows: 2, darwin: 3, other: 4) }
  it { should validate_uniqueness_of(:token) }
  it { should belong_to(:user) }
  it { should have_many(:tasks) }
  it { should have_and_belong_to_many(:projects) }
  it { should have_many(:hashcat_benchmarks) }
  it { should have_db_column(:command_parameters).of_type(:text) }
  it { should have_db_column(:cpu_only).of_type(:boolean).with_options(default: false) }
  it { should have_db_column(:devices).of_type(:string).with_options(default: []) }
  it { should have_db_column(:ignore_errors).of_type(:boolean).with_options(default: false) }
  it { should have_db_column(:trusted).of_type(:boolean).with_options(default: false) }
  it { should have_readonly_attribute(:token) }

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
end
