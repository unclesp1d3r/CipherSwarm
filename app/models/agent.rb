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
class Agent < ApplicationRecord
  audited except: [ :last_seen_at, :last_ipaddress, :updated_at ]
  belongs_to :user, touch: true
  has_and_belongs_to_many :projects, touch: true
  has_many :tasks, dependent: :destroy
  has_many :hashcat_benchmarks, dependent: :destroy
  validates_uniqueness_of :token
  has_secure_token :token # Generates a unique token for the agent.
  attr_readonly :token # The token should not be updated after creation.
  before_create :set_update_interval

  validates_presence_of :name
  validates_presence_of :user

  broadcasts_refreshes

  # The operating system of the agent.
  enum operating_system: { unknown: 0, linux: 1, windows: 2, darwin: 3, other: 4 }

  def last_benchmark_date
    return nil if hashcat_benchmarks.empty?
    hashcat_benchmarks.order(benchmark_date: :desc).first.benchmark_date
  end

  def last_benchmarks
    return nil if hashcat_benchmarks.empty?
    hashcat_benchmarks.where(benchmark_date: hashcat_benchmarks.select("MAX(benchmark_date)"))
  end

  def advanced_configuration=(value)
    self[:advanced_configuration] = value.is_a?(String) ? JSON.parse(value) : value
  end

  # Sets the update interval for the agent.
  #
  # This method generates a random number between 5 and 15 and assigns it to the
  # "agent_update_interval" key in the advanced_configuration hash.
  #
  # Example:
  #   agent.set_update_interval
  #
  # Returns:
  #   The updated agent object.
  def set_update_interval
    interval = rand(5..15)
    self.advanced_configuration["agent_update_interval"] = interval
  end

  def allowed_hash_types
    hashcat_benchmarks.distinct.pluck(:hash_type)
  end

  # Retrieves the first pending task for the agent.
  #
  # Returns:
  # - The first pending task for the agent, or nil if no pending tasks are found.
  def new_task
    # We'll start with no prioritization, just get the first pending task.
    # We can add prioritization later.

    # first we assign any tasks that are assigned to the agent and are incomplete.
    incomplete_task = tasks.incomplete.first
    return nil if incomplete_task.attack.completed?
    return incomplete_task if incomplete_task.present?

    # First we'll check if we have any pending tasks assigned to the agent.
    pending_tasks = tasks.pending.first
    return pending_tasks if pending_tasks.present?

    # Let's assume no pending tasks are found.
    # First we'll find some pending attacks.

    campaigns = Campaign.in_projects(project_ids).order(created_at: :desc)
    return nil if campaigns.blank?
    campaigns.each do |campaign|
      campaign.attacks.pending.each do |attack|
        return tasks.create(attack: attack, status: :pending, start_date: Time.now)
      end
    end

    # If no pending tasks are found, we'll return nil.
    nil
  end
end
