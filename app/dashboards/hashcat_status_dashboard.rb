require "administrate/base_dashboard"

class HashcatStatusDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    device_statuses: Field::HasMany,
    estimated_stop: Field::DateTime,
    hashcat_guesses: Field::HasMany,
    original_line: Field::Text,
    progress: Field::Number,
    recovered_hashes: Field::Number,
    recovered_salts: Field::Number,
    rejected: Field::Number,
    restore_point: Field::Number,
    session: Field::String,
    status: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    target: Field::String,
    task: Field::BelongsTo,
    time: Field::DateTime,
    time_start: Field::DateTime,
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
    status
    time
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    device_statuses
    estimated_stop
    hashcat_guesses
    original_line
    progress
    recovered_hashes
    recovered_salts
    rejected
    restore_point
    session
    status
    target
    task
    time
    time_start
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    device_statuses
    estimated_stop
    hashcat_guesses
    original_line
    progress
    recovered_hashes
    recovered_salts
    rejected
    restore_point
    session
    status
    target
    task
    time
    time_start
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

  # Overwrite this method to customize how hashcat statuses are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(hashcat_status)
  #   "HashcatStatus ##{hashcat_status.id}"
  # end
end