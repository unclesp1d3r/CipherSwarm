require "administrate/base_dashboard"

class AgentDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    active: Field::Boolean,
    advanced_configuration: Field::JSONB.with_options(
      transform: [ :parse_json ],
      advanced_view: { use_native_hashcat: Field::Boolean,
                       agent_update_interval: Field::Number
      }
    ),
    client_signature: Field::Text,
    command_parameters: Field::Text,
    cpu_only: Field::Boolean,
    devices: Field::String,
    ignore_errors: Field::Boolean,
    last_ipaddress: Field::String,
    last_seen_at: Field::DateTime.with_options(format: :short),
    name: Field::String,
    operating_system: Field::Enum,
    projects: Field::HasMany,
    token: Field::String,
    trusted: Field::Boolean,
    user: Field::BelongsTo,
    created_at: Field::DateTime.with_options(format: :short),
    updated_at: Field::DateTime.with_options(format: :short)
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    name
    active
    trusted
    operating_system
    client_signature
    last_seen_at
    last_ipaddress
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    name
    active
    trusted
    user
    client_signature
    command_parameters
    cpu_only
    devices
    ignore_errors
    last_ipaddress
    last_seen_at
    operating_system
    projects
    token
    advanced_configuration
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    name
    projects
    active
    command_parameters
    cpu_only
    ignore_errors
    trusted
    user
    advanced_configuration
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

  # Overwrite this method to customize how agents are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(agent)
    agent.name
  end
end