# frozen_string_literal: true

require "administrate/base_dashboard"

class HashListDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    description: Field::Text,
    file: Field::ActiveStorage.with_options({ direct_upload: true }),
    hash_items: Field::HasMany,
    hash_type: Field::BelongsTo,
    name: Field::String,
    project: Field::BelongsTo,
    sensitive: Field::Boolean,
    created_at: Field::DateTime.with_options(format: :short),
    updated_at: Field::DateTime.with_options(format: :short),
    processed: Field::Boolean,
    metadata_fields_count: Field::Number,
    separator: Field::String,
    salt: Field::Boolean,
    uncracked_list: Field::Text.with_options(searchable: false),
    cracked_list: Field::Text.with_options(searchable: false),
    completion: Field::String.with_options(searchable: false)
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    name
    description
    hash_type
    project
    processed
    completion
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    name
    description
    completion
    project
    file
    hash_type
    metadata_fields_count
    sensitive
    hash_items
    processed
    separator
    salt
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    name
    description
    hash_type
    file
    project
    sensitive
    metadata_fields_count
    separator
    salt
  ].freeze

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

  # Overwrite this method to customize how hash lists are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(hash_list)
    "#{hash_list.name} (#{hash_list.hash_type.name})"
  end
end
