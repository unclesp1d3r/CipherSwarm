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
FactoryBot.define do
  factory :agent do
    id { 1 }
    client_signature { "test client" }
    command_parameters { "-D 1,2" }
    cpu_only { false }
    ignore_errors { false }
    active { true }
    trusted { false }
    last_ipaddress { "127.0.0.1" }
    last_seen_at { "2024-03-01 23:12:50" }
    name { "test_agent" }
    operating_system { :darwin }
    association :user, factory: :first_user
    devices { [ "Device 1", "Device 2" ] }
  end
end
