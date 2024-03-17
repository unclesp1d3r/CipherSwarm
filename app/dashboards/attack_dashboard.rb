require "administrate/base_dashboard"

class AttackDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    attack_mode: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    classic_markov: Field::Boolean,
    custom_charset_1: Field::String,
    custom_charset_2: Field::String,
    custom_charset_3: Field::String,
    custom_charset_4: Field::String,
    description: Field::Text,
    disable_markov: Field::Boolean,
    increment_maximum: Field::Number,
    increment_minimum: Field::Number,
    increment_mode: Field::Boolean,
    left_rule: Field::String,
    markov_threshold: Field::Number,
    mask: Field::String,
    name: Field::String,
    optimized: Field::Boolean,
    right_rule: Field::String,
    rule_lists: Field::HasMany,
    slow_candidate_generators: Field::Boolean,
    type: Field::String,
    word_lists: Field::HasMany,
    workload_profile: Field::Number,
    hashcat_parameters: Field::String,
    campaign: Field::BelongsTo,
    cracker: Field::BelongsTo,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    campaign
    name
    attack_mode
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = {
    "" => [ :id, :name, :description, :attack_mode, :campaign, :cracker ],
    "Dictionary & Rules" => [ :word_lists, :rule_lists ],
    "Combination" => [ :left_rule, :right_rule ],
    "Mask Attack" => [ :mask ],
    "Increment" => [ :increment_mode, :increment_minimum, :increment_maximum ],
    "Character Sets" => [ :custom_charset_1, :custom_charset_2, :custom_charset_3, :custom_charset_4 ],
    "Markov" => [ :classic_markov, :disable_markov, :markov_threshold ],
    "Optimization" => [ :optimized, :slow_candidate_generators ],
    "Workload Profile" => [ :workload_profile ],
    "Advanced" => [ :hashcat_parameters ]
  }

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = {
    "" => [ :name, :description, :attack_mode, :campaign, :cracker ],
    "Dictionary & Rules" => [ :word_lists, :rule_lists ],
    "Combination" => [ :left_rule, :right_rule ],
    "Mask Attack" => [ :mask ],
    "Increment" => [ :increment_mode, :increment_minimum, :increment_maximum ],
    "Character Sets" => [ :custom_charset_1, :custom_charset_2, :custom_charset_3, :custom_charset_4 ],
    "Markov" => [ :classic_markov, :disable_markov, :markov_threshold ],
    "Optimization" => [ :optimized, :slow_candidate_generators ],
    "Workload Profile" => [ :workload_profile ]
  }

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how templates are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(attack)
    "#{attack.name}"
  end
end
