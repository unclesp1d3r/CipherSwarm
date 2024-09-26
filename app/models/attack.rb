# frozen_string_literal: true

##
# The Attack class represents an attack in the system.
# It maintains the relationships to other models and handles the state and behavior of an attack.
#
# == Schema Information
#
# Table name: attacks
#
#  id                                                                                                  :bigint           not null, primary key
#  attack_mode(Hashcat attack mode)                                                                    :integer          default("dictionary"), not null, indexed
#  classic_markov(Is classic Markov chain enabled?)                                                    :boolean          default(FALSE), not null
#  complexity_value(Complexity value of the attack)                                                    :decimal(, )      default(0.0), not null, indexed
#  custom_charset_1(Custom charset 1)                                                                  :string           default("")
#  custom_charset_2(Custom charset 2)                                                                  :string           default("")
#  custom_charset_3(Custom charset 3)                                                                  :string           default("")
#  custom_charset_4(Custom charset 4)                                                                  :string           default("")
#  deleted_at                                                                                          :datetime         indexed
#  description(Attack description)                                                                     :text             default("")
#  disable_markov(Is Markov chain disabled?)                                                           :boolean          default(FALSE), not null
#  end_time(The time the attack ended.)                                                                :datetime
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
#  start_time(The time the attack started.)                                                            :datetime
#  state                                                                                               :string           indexed
#  type                                                                                                :string
#  workload_profile(Hashcat workload profile (e.g. 1 for low, 2 for medium, 3 for high, 4 for insane)) :integer          default(3), not null
#  created_at                                                                                          :datetime         not null
#  updated_at                                                                                          :datetime         not null
#  campaign_id                                                                                         :bigint           not null, indexed
#  mask_list_id(The mask list used for the attack.)                                                    :bigint           indexed
#  rule_list_id(The rule list used for the attack.)                                                    :bigint           indexed
#  word_list_id(The word list used for the attack.)                                                    :bigint           indexed
#
# Indexes
#
#  index_attacks_campaign_id          (campaign_id)
#  index_attacks_on_attack_mode       (attack_mode)
#  index_attacks_on_complexity_value  (complexity_value)
#  index_attacks_on_deleted_at        (deleted_at)
#  index_attacks_on_mask_list_id      (mask_list_id)
#  index_attacks_on_rule_list_id      (rule_list_id)
#  index_attacks_on_state             (state)
#  index_attacks_on_word_list_id      (word_list_id)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => campaigns.id) ON DELETE => cascade
#  fk_rails_...  (mask_list_id => mask_lists.id) ON DELETE => cascade
#  fk_rails_...  (rule_list_id => rule_lists.id) ON DELETE => cascade
#  fk_rails_...  (word_list_id => word_lists.id) ON DELETE => cascade
#
class Attack < ApplicationRecord
  acts_as_paranoid # Soft deletes the attack

  ##
  # Associations
  #
  belongs_to :campaign, counter_cache: true
  has_many :tasks, dependent: :destroy, autosave: true
  has_many :hash_items, dependent: :nullify
  has_one :hash_list, through: :campaign
  belongs_to :rule_list, optional: true
  belongs_to :mask_list, optional: true
  belongs_to :word_list, optional: true

  # Validations
  validates :attack_mode, presence: true,
                          inclusion: { in: %w[dictionary mask hybrid_dictionary hybrid_mask] }
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 65_535 }
  validates :increment_mode, inclusion: { in: [true, false] }
  validates :increment_minimum, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :increment_maximum, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :markov_threshold, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :slow_candidate_generators, inclusion: { in: [true, false] }
  validates :optimized, inclusion: { in: [true, false] }
  validates :disable_markov, inclusion: { in: [true, false] }
  validates :classic_markov, inclusion: { in: [true, false] }
  validates :workload_profile, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 4 }
  validates :mask, length: { maximum: 512 }, allow_nil: true

  ##
  # Conditional Associations
  #
  with_options if: -> { dictionary? } do
    validates :word_list, presence: true
    validates_associated :word_list
    validates :mask, absence: true
    validates :mask_list, absence: true, allow_blank: true
    validates :increment_mode, comparison: { equal_to: false }, allow_blank: true
  end

  with_options if: -> { mask? } do
    validate :validate_mask_or_mask_list
    validates :word_list, absence: true
    validates :increment_minimum, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true, if: -> { increment_mode? }
    validates :increment_minimum, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true, if: -> { increment_mode? }
    validates :rule_list, absence: true, allow_blank: true
    validates :markov_threshold, comparison: { equal_to: 0 }, allow_blank: true
  end

  with_options if: -> { hybrid_dictionary? } do
    validates :word_list, presence: true
    validates_associated :word_list
    validates :mask, presence: true
    validates :mask_list, absence: true, allow_blank: true
    validates :increment_mode, comparison: { equal_to: false }, allow_blank: true
    validates :rule_list, absence: true, allow_blank: true
    validates :markov_threshold, comparison: { equal_to: 0 }, allow_blank: true
  end

  with_options if: -> { hybrid_mask? } do
    validates :word_list, presence: true
    validates_associated :word_list
    validates :mask, presence: true
    validates :mask_list, absence: true
    validates :increment_mode, comparison: { equal_to: false }, allow_blank: true
    validates :markov_threshold, comparison: { equal_to: 0 }, allow_blank: true
  end

  # Enumerations
  enum :attack_mode, { dictionary: 0, mask: 3, hybrid_dictionary: 6, hybrid_mask: 7 }

  ##
  # Scopes
  #
  default_scope { order(:complexity_value, :created_at) } # We want the highest priority attack first
  scope :pending, -> { with_state(:pending) }
  scope :incomplete, -> { without_states(:completed, :exhausted, :running, :paused) }
  scope :active, -> { with_states(:running, :pending) }

  # Broadcasts a refresh to the client when the attack is updated unless running in test environment

  broadcasts_refreshes unless Rails.env.test?

  ##
  # Delegations
  #
  delegate :uncracked_count, to: :campaign, allow_nil: true # Delegates the uncracked_count method to the campaign

  # Callbacks
  after_create_commit :update_stored_complexity # Updates the stored complexity value after the attack is created

  ##
  # State Machine
  #
  state_machine :state, initial: :pending do
    # Trigger that an agent has accepted the attack. This can only be triggered when the attack is in the pending state.
    event :accept do
      transition all - %i[completed exhausted] => :running
    end

    # Trigger that the attack has been started. This can only be triggered when the attack is in the pending state.
    event :run do
      transition pending: :running
    end

    # Trigger that the attack has been completed. If the attack is in the running state, it will transition to the completed state
    # if all tasks are completed or the hash list is fully cracked. If the attack is in the pending state, it will transition to the
    # completed state if the hash list is fully cracked.
    event :complete do
      transition running: :completed if ->(attack) { attack.tasks.all?(&:completed?) || attack.campaign.completed? }
      transition pending: :completed if ->(attack) { attack.hash_list.uncracked_count.zero? }
      transition all - [:running] => same
    end

    # Trigger that the attack has been paused. If the attack is in the running or pending state, it will transition to the paused state.
    event :pause do
      transition %i[running pending] => :paused
      transition any => same
    end

    # Trigger that the attack has encountered an error. If the attack is in the running state, it will transition to the failed state.
    event :error do
      transition running: :failed
      transition any => same
    end

    # Trigger that the attack has been exhausted. If the attack is in the running state, it will transition to the completed state
    # if all tasks are exhausted. If the attack is in the running state, it will transition to the completed state if the hash list
    # is fully cracked.
    event :exhaust do
      transition running: :completed if ->(attack) { attack.tasks.all?(&:exhausted?) }
      transition running: :completed if ->(attack) { attack.hash_list.uncracked_count.zero? }
      transition any => same
    end

    # Trigger that the attack has been canceled. If the attack is in the pending or running state, it will transition to the failed state.
    event :cancel do
      transition %i[pending running] => :failed
    end

    # Trigger that the attack has been reset. If the attack is in the failed, completed, or exhausted state, it will transition to the pending state.
    # This is only used when the attack needs to be re-run, such as when it has been modified, the hash list has changed, etc.
    event :reset do
      transition %i[failed completed exhausted] => :pending
    end

    # Trigger that the attack is being resumed. If the attack is in the paused state, it will transition to the pending state.
    event :resume do
      transition paused: :pending
      transition any => same
    end

    # Trigger that the agent has abandoned the attack. If the attack is in the running state, it will transition to the pending state.
    # This is to free the attack up for another agent to pick up.
    event :abandon do
      transition running: :pending
      transition any => same
    end

    ## Transitions

    # Executed after an attack has entered the running state. This sets the start_time attribute to the current time.
    after_transition on: :running do |attack|
      attack.touch(:start_time) # rubocop:disable Rails/SkipsModelValidations
      attack.campaign.touch # rubocop:disable Rails/SkipsModelValidations
    end

    # Executed after an attack has entered the completed state. This sets the end_time attribute to the current time.
    after_transition on: :complete do |attack|
      attack.touch(:end_time) # rubocop:disable Rails/SkipsModelValidations
    end

    # Executed after an attack has been abandoned. This removes all tasks associated with the attack.
    after_transition on: :abandon do |attack|
      # If the attack is abandoned, we should remove the tasks to free up for another agent and touch the campaign to update the updated_at timestamp
      attack.tasks.destroy_all
      attack.campaign.touch # rubocop:disable Rails/SkipsModelValidations
    end

    # Executed after an attack is being paused. This pauses all tasks associated with the attack.
    after_transition any => :paused, :do => :pause_tasks

    # Executed after an attack is being resumed. This resumes all tasks associated with the attack.
    after_transition paused: any, do: :resume_tasks

    # Executed after an attack has been completed. This completes the hash list for the campaign and updates the campaign's updated_at timestamp.
    after_transition any => :completed, :do => :complete_hash_list
    after_transition any => :completed, :do => :touch_campaign

    # Executed before an attack is marked completed. This completes all remaining tasks associated with the attack if the hash list is fully cracked.
    before_transition on: :complete do |attack|
      attack.tasks.each(&:complete!) if attack.hash_list.uncracked_count.zero?
    end

    state :paused
    state :failed
    state :exhausted
    state :pending
  end

  ##
  # Checks if the attack is completed.
  #
  # @return [Boolean] true if the attack is completed, otherwise false.
  def completed?
    self.state == "completed"
  end

  # Calculates the estimated complexity of an attack based on the attack mode.
  #
  # @return [BigDecimal] the estimated complexity value.
  def estimated_complexity
    case attack_mode
    when "dictionary"
      calculate_dictionary_complexity
    when "mask"
      calculate_mask_complexity
    else
      BigDecimal(0)
    end
  end

  # Estimates the finish time of the attack.
  #
  # This method retrieves the first running task associated with the attack
  # and returns its estimated finish time.
  #
  # @return [Time, nil] The estimated finish time of the attack, or nil if no running task is found.
  def estimated_finish_time
    current_task&.estimated_finish_time
  end

  # Returns the name of the agent associated with the most recently updated running task.
  # The method looks for tasks that are in the 'running' state, orders them by the 'updated_at' timestamp in descending order,
  # and retrieves the agent's name from the first task in the list.
  #
  # @return [String, nil] the name of the agent or nil if no such task or agent exists.
  def executing_agent
    current_task&.agent&.name
  end

  # Forces an update to the complexity calculation of the attack and saves the changes.
  #
  # This method calls the `update_stored_complexity` method and saves the record.
  # Useful when there are changes in related entities that may affect the attack's complexity.
  def force_complexity_update
    update_stored_complexity
  end

  # Returns the hash mode of the associated campaign's hash list.
  #
  # @return [Integer] the hash mode of the campaign's hash list
  def hash_type
    campaign.hash_list.hash_mode
  end

  # Generates a string of parameters to be used with Hashcat based on the attributes of the Attack model.
  #
  # The parameters include:
  # - Attack mode (-a)
  # - Markov threshold (--markov-threshold) if classic markov is enabled
  # - Optimized mode (-O) if enabled
  # - Increment mode (--increment) if enabled
  # - Increment minimum (--increment-min) if increment mode is enabled
  # - Increment maximum (--increment-max) if increment mode is enabled
  # - Markov disable (--markov-disable) if markov is disabled
  # - Markov classic (--markov-classic) if classic markov is enabled
  # - Markov threshold (-t) if present
  # - Slow candidate generators (-S) if enabled
  # - Custom charset 1 (-1) if present
  # - Custom charset 2 (-2) if present
  # - Custom charset 3 (-3) if present
  # - Custom charset 4 (-4) if present
  # - Workload profile (-w)
  # - Word list file if present
  # - Mask list file if present
  # - Rule list file (-r) if present
  #
  # @return [String] A string of parameters to be used with Hashcat.
  def hashcat_parameters
    parameters = []
    parameters << attack_mode_param
    parameters << markov_threshold_param if classic_markov
    parameters << "-O" if optimized
    parameters << increment_mode_param if increment_mode
    parameters << "--markov-disable" if disable_markov
    parameters << "--markov-classic" if classic_markov
    parameters << "-t #{markov_threshold}" if markov_threshold.present?
    parameters << "-S" if slow_candidate_generators
    parameters << custom_charset_params
    parameters << "-w #{workload_profile}"
    parameters << file_params
    parameters.compact.join(" ")
  end

  # Calculates the percentage of completion for the running task.
  #
  # @return [Float] the progress percentage of the running task, or 0.00 if no task is running.
  def percentage_complete
    current_task&.progress_percentage || 0.00
  end

  ##
  # Generates a human-readable text for progress.
  #
  # @return [String, nil] the progress text.
  def progress_text
    current_task&.progress_text
  end

  # Calculates the duration between the start and end times.
  #
  # @return [Float, nil] the difference between end_time and start_time in seconds,
  #   or nil if either start_time or end_time is not set.
  def run_time
    start_time.nil? || end_time.nil? || start_time > end_time ? nil : end_time - start_time
  end

  def to_full_label
    "#{campaign.name} - #{to_label}"
  end

  # Returns a string representation of the attack instance, combining the name and attack mode.
  #
  # @return [String] a formatted string in the form of "name (attack_mode)"
  def to_label
    "#{name} (#{attack_mode})"
  end

  # Returns a string representation of the attack instance, combining the name, attack mode, and complexity.
  #
  # @return [String] a formatted string in the form of "name (attack_mode) - complexity"
  def to_label_with_complexity
    "#{to_label} #{complexity_as_words}"
  end

  private

  # Generates the attack mode parameter for Hashcat.
  #
  # @return [String] the attack mode parameter.
  def attack_mode_param
    "-a #{Attack.attack_modes[attack_mode]}"
  end

  # Calculates the complexity for dictionary attack mode.
  #
  # This method calculates the complexity based on the number of lines in the word list
  # and the rule list. If the rule list is empty, the complexity is equal to the number
  # of lines in the word list. If the rule list is not empty, the complexity is the product
  # of the number of lines in the word list and the number of lines in the rule list.
  # If increment mode is enabled, the complexity is multiplied by the size of the increment range.
  #
  # @return [BigDecimal] the calculated complexity value.
  def calculate_dictionary_complexity
    word_list_lines = word_list&.line_count || 0
    rule_list_lines = rule_list&.line_count || 0
    complexity = rule_list_lines.zero? ? word_list_lines : word_list_lines * rule_list_lines
    complexity *= increment_range_size if increment_mode
    complexity.to_d
  end

  # Calculates the complexity for mask attack mode.
  def calculate_mask_complexity
    return mask_list.complexity_value if mask_list.present?
    return BigDecimal("0.0") if mask.blank?
    MaskCalculationMethods.calculate_mask_candidates(mask)
  end

  # Generates the custom charset parameter for Hashcat.
  #
  # @param index [Integer] the index of the custom charset (1 to 4).
  # @return [String, nil] the custom charset parameter if present, otherwise nil.
  def charset_param(index)
    value = send("custom_charset_#{index}")
    "-#{index} #{value}" if value.present?
  end

  # Completes the hash list for the campaign if there are no uncracked hashes left.
  #
  # This method checks if the campaign has zero uncracked hashes. If true, it iterates
  # through all incomplete attacks associated with the campaign and marks them as complete.
  #
  # @return [void]
  def complete_hash_list
    return unless campaign.uncracked_count.zero?
    campaign.attacks.incomplete.each(&:complete)
  end

  # Converts the estimated complexity into a human-readable string representation.
  #
  # @return [String] A string representing the complexity in words or symbols.
  def complexity_as_words
    case complexity_value
    when 0
      "🤷"
    when 1..1_000
      "😃"
    when 1_001..1_000_000
      "😐"
    when 1_000_001..1_000_000_000
      "😟"
    when 1_000_000_001..1_000_000_000_000
      "😳"
    else
      "😱"
    end
  end

  # Returns the complexity value for a given element.
  #
  # @param element [String] the element for which to calculate the complexity value.
  # @return [Integer] the complexity value for the given element.
  def complexity_value_for_element(element)
    COMPLEXITY_VALUES[element] || custom_charset_length(element) || 1
  end

  # Returns the current running task for the attack.
  #
  # This method retrieves the task associated with the attack that is in the 'running' state,
  # orders them by the 'updated_at' timestamp in descending order, and returns the first task in the list.
  #
  # @return [Task, nil] the current running task or nil if no such task exists.
  def current_task
    tasks.with_state(:running).order(updated_at: :desc).first
  end

  # Returns the length of the custom charset for the given element.
  #
  # @param element [String] the element for which to retrieve the custom charset length.
  # @return [Integer] the length of the custom charset.
  def custom_charset_length(element)
    case element
    when "?1" then custom_charset_1.length
    when "?2" then custom_charset_2.length
    when "?3" then custom_charset_3.length
    when "?4" then custom_charset_4.length
    else
      0
    end
  end

  # Generates the custom charset parameters for Hashcat.
  #
  # This method iterates through the custom charsets (1 to 4) and generates
  # the corresponding parameters for each charset that is present.
  #
  # @return [String] A string of custom charset parameters.
  def custom_charset_params
    (1..4).map { |i| charset_param(i) }.compact.join(" ")
  end

  # Generates the file parameters for Hashcat.
  #
  # This method retrieves the filenames of the word list and mask list,
  # and includes the rule list file if present.
  #
  # @return [String] A string of file parameters.
  def file_params
    [word_list, mask_list].compact.map { |list| list.file.filename }.join(" ") +
      (rule_list.present? ? " -r #{rule_list.file.filename}" : "")
  end

  # Generates the increment mode parameters for Hashcat.
  #
  # This method constructs the parameters for enabling increment mode in Hashcat,
  # including the minimum and maximum increment values.
  #
  # @return [String] A string of increment mode parameters.
  def increment_mode_param
    ["--increment", "--increment-min #{increment_minimum}", "--increment-max #{increment_maximum}"].join(" ")
  end

  # Calculates the size of the increment range.
  #
  # @return [Integer] the size of the increment range.
  def increment_range_size
    (increment_minimum..increment_maximum).to_a.size
  end

  # Generates the Markov threshold parameter for Hashcat.
  #
  # @return [String] the Markov threshold parameter.
  def markov_threshold_param
    "--markov-threshold=#{markov_threshold}"
  end

  # Pauses all tasks associated with the current object.
  # Iterates through each task and calls the `pause` method on it.
  def pause_tasks
    tasks.without_state(:paused).each(&:pause)
  end

  # Resumes all tasks associated with the current object.
  # Iterates through each task and calls the `resume` method on it.
  def resume_tasks
    tasks.find_each(&:resume)
  end

  # Updates the `updated_at` timestamp of the associated campaign.
  #
  # This method calls the `touch` method on the campaign, which updates
  # the `updated_at` timestamp to the current time.
  #
  # @return [void]
  def touch_campaign
    campaign.touch # rubocop:disable Rails/SkipsModelValidations
  end

  # Updates the stored complexity value of the attack.
  #
  # This method calculates the estimated complexity of the attack
  # and updates the `complexity_value` attribute with the calculated value.
  #
  # @return [Boolean] true if the record was successfully updated, false otherwise.
  def update_stored_complexity
    update(complexity_value: estimated_complexity)
  end

  # Validates the presence of either `mask` or `mask_list`.
  # If both `mask` and `mask_list` are blank, adds errors to both attributes.
  #
  # @return [void]
  def validate_mask_or_mask_list
    return unless mask.blank? && mask_list.blank?
    errors.add(:mask, "must be present if mask lists are not present")
    errors.add(:mask_list, "must be present if mask is not present")
  end
end
