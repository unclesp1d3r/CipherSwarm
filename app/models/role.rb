# frozen_string_literal: true

# The Role model represents a role that can be assigned to users within the application.
# It supports polymorphic associations to different resources and uses the Rolify gem
# for role management.
#
# Associations:
# - has_and_belongs_to_many :users, join_table: :users_roles
# - belongs_to :resource (polymorphic, optional)
#
# Validations:
# - Validates that the resource_type is included in the list of Rolify resource types, allowing nil values.
#
# Scopes:
# - Uses the scopify method provided by the Rolify gem to add scope methods for roles.
#
# == Schema Information
#
# Table name: roles
#
#  id            :bigint           not null, primary key
#  name          :string           indexed => [resource_type, resource_id]
#  resource_type :string           indexed => [name, resource_id], indexed => [resource_id]
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  resource_id   :bigint           indexed => [name, resource_type], indexed => [resource_type]
#
# Indexes
#
#  index_roles_on_name_and_resource_type_and_resource_id  (name,resource_type,resource_id)
#  index_roles_on_resource                                (resource_type,resource_id)
#
class Role < ApplicationRecord
  has_and_belongs_to_many :users, join_table: :users_roles

  belongs_to :resource,
             polymorphic: true,
             optional: true

  validates :resource_type,
            inclusion: { in: Rolify.resource_types },
            allow_nil: true

  scopify
end
