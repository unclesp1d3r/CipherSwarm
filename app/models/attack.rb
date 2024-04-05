# == Schema Information
#
# Table name: operations
#
#  id                                                                                                  :bigint           not null, primary key
#  attack_mode(Hashcat attack mode)                                                                    :integer          default("dictionary"), not null, indexed
#  classic_markov(Is classic Markov chain enabled?)                                                    :boolean          default(FALSE), not null
#  custom_charset_1(Custom charset 1)                                                                  :string           default("")
#  custom_charset_2(Custom charset 2)                                                                  :string           default("")
#  custom_charset_3(Custom charset 3)                                                                  :string           default("")
#  custom_charset_4(Custom charset 4)                                                                  :string           default("")
#  description(Attack description)                                                                     :text             default("")
#  disable_markov(Is Markov chain disabled?)                                                           :boolean          default(FALSE), not null
#  increment_maximum(Hashcat increment maximum)                                                        :integer          default(0)
#  increment_minimum(Hashcat increment minimum)                                                        :integer          default(0)
#  increment_mode(Is the attack using increment mode?)                                                 :boolean          default(FALSE), not null
#  left_rule(Left rule)                                                                                :string           default("")
#  markov_threshold(Hashcat Markov threshold (e.g. 1000))                                              :integer          default(0)
#  mask(Hashcat mask (e.g. ?a?a?a?a?a?a?a?a))                                                          :string           default("")
#  name(Attack name)                                                                                   :string           default(""), not null
#  optimized(Is the attack optimized?)                                                                 :boolean          default(FALSE), not null
#  priority(The priority of the attack, higher numbers are higher priority.)                           :integer          default(0), not null
#  right_rule(Right rule)                                                                              :string           default("")
#  slow_candidate_generators(Are slow candidate generators enabled?)                                   :boolean          default(FALSE), not null
#  state                                                                                               :string           indexed
#  type                                                                                                :string
#  workload_profile(Hashcat workload profile (e.g. 1 for low, 2 for medium, 3 for high, 4 for insane)) :integer          default(3), not null
#  created_at                                                                                          :datetime         not null
#  updated_at                                                                                          :datetime         not null
#  campaign_id                                                                                         :bigint           indexed
#
# Indexes
#
#  index_operations_on_attack_mode  (attack_mode)
#  index_operations_on_campaign_id  (campaign_id)
#  index_operations_on_state        (state)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id)
#
class Attack < Operation
  belongs_to :campaign, touch: true
  has_many :tasks, dependent: :destroy, inverse_of: :attack
  has_one :hash_list, through: :campaign
  scope :pending, -> { with_state(:pending) }
  scope :incomplete, -> { without_states(:completed, :running, :paused) }

  broadcasts_refreshes unless Rails.env.test?

  state_machine :state, initial: :pending do
    event :accept do
      transition all - [ :completed ] => :running
    end

    event :run do
      transition pending: :running
    end

    event :complete do
      transition running: :completed if ->(attack) { attack.tasks.all?(&:completed?) }
      transition pending: :completed if ->(attack) { attack.hash_list.uncracked_count.zero? }
    end

    event :pause do
      transition running: :paused
    end

    event :error do
      transition running: :failed
    end

    event :exhaust do
      transition running: :exhausted if ->(attack) { attack.tasks.all?(&:exhausted?) }
      transition running: :completed if ->(attack) { attack.hash_list.uncracked_count.zero? }
      transition all - [ :running ] => same
    end

    event :cancel do
      transition [ :pending, :running ] => :failed
    end

    before_transition on: :pause do |attack|
      attack.tasks.each(&:pause!)
    end

    before_transition on: :complete do |attack|
      if attack.hash_list.uncracked_count == 0
        attack.tasks.each(&:complete!) if attack.tasks.any?(&:pending?)
      end
    end

    state :completed do
      validates :tasks, presence: true
    end
    state :running do
      validates :tasks, presence: true
    end
    state :paused
    state :failed
    state :exhausted
    state :pending
  end

  def hash_type
    campaign.hash_list.hash_mode
  end
end
