# == Schema Information
#
# Table name: agents
#
#  id                                                                                           :bigint           not null, primary key
#  active(Is the agent active)                                                                  :boolean          default(TRUE)
#  allow_device_to_change_name(Allow the device to change its name to match the agent hostname) :boolean          default(TRUE)
#  client_signature(The signature of the agent)                                                 :text
#  command_parameters(Parameters to be passed to the agent when it checks in)                   :text
#  cpu_only(Only use for CPU only tasks)                                                        :boolean          default(FALSE)
#  ignore_errors(Ignore errors, continue to next task)                                          :boolean          default(FALSE)
#  last_ipaddress(Last known IP address)                                                        :string           default("")
#  last_seen_at(Last time the agent checked in)                                                 :datetime
#  name(Name of the agent)                                                                      :string           default("")
#  operating_system(Operating system of the agent)                                              :integer          default("linux")
#  token(Token used to authenticate the agent)                                                  :string(24)       indexed
#  trusted(Is the agent trusted to handle sensitive data)                                       :boolean          default(FALSE)
#  created_at                                                                                   :datetime         not null
#  updated_at                                                                                   :datetime         not null
#  user_id(The user that the agent is associated with)                                          :bigint           indexed
#
# Indexes
#
#  index_agents_on_token    (token) UNIQUE
#  index_agents_on_user_id  (user_id)
#
class Agent < ApplicationRecord
  belongs_to :user
  has_and_belongs_to_many :projects
  has_secure_token :token
  attr_readonly :token

  validates_presence_of :name
  validates_presence_of :name
  validates_presence_of :user

  enum operating_system: [ unknown: 0, linux: 1, windows: 2, macos: 3, other: 4 ]
end
