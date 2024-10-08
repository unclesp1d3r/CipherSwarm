# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

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
    attack_mode: Field::Select.with_options(searchable: false, collection: lambda { |field|
                                              field.resource.class.send(field.attribute.to_s.pluralize).keys
                                            }),
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
    mask_list: Field::BelongsTo,
    name: Field::String,
    optimized: Field::Boolean,
    right_rule: Field::String,
    rule_list: Field::BelongsTo,
    slow_candidate_generators: Field::Boolean,
    type: Field::String,
    word_list: Field::BelongsTo.with_options(include_blank: true),
    workload_profile: Field::Number,
    hashcat_parameters: Field::String,
    campaign: Field::BelongsTo,
    tasks: Field::HasMany,
    state: Field::String,
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
    state
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = {
    "" => %i[id name description attack_mode campaign state],
    "Dictionary & Rules" => %i[word_list rule_list],
    "Combination" => %i[left_rule right_rule],
    "Mask Attack" => %i[mask mask_list],
    "Increment" => %i[increment_mode increment_minimum increment_maximum],
    "Character Sets" => %i[custom_charset_1 custom_charset_2 custom_charset_3 custom_charset_4],
    "Markov" => %i[classic_markov disable_markov markov_threshold],
    "Optimization" => %i[optimized slow_candidate_generators],
    "Workload Profile" => [:workload_profile],
    "Advanced" => %i[hashcat_parameters tasks created_at updated_at]
  }

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = {
    "" => %i[name description attack_mode campaign],
    "Dictionary & Rules" => %i[word_list rule_list],
    "Combination" => %i[left_rule right_rule],
    "Mask Attack" => %i[mask mask_list],
    "Increment" => %i[increment_mode increment_minimum increment_maximum],
    "Character Sets" => %i[custom_charset_1 custom_charset_2 custom_charset_3 custom_charset_4],
    "Markov" => %i[classic_markov disable_markov markov_threshold],
    "Optimization" => %i[optimized slow_candidate_generators],
    "Workload Profile" => [:workload_profile]
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
