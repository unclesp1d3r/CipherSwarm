# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Role Class
#
# This class represents roles that can be assigned to users or associated with resources in a polymorphic manner.
#
# === Associations
#
# - `has_and_belongs_to_many :users`: Establishes a many-to-many relationship with the `User` model
#   through the join table `users_roles`.
# - `belongs_to :resource`: Sets up a polymorphic association with any resource model. This
#   association is optional.
#
# === Validations
#
# - Validates that the `resource_type` is included in a list of allowed resource types
#   defined by `Rolify.resource_types`. Null values are permitted for `resource_type`.
#
# === Scopes
#
# - Includes Rolify's `scopify` method for adding scopes to roles.
#
# === Usage
#
# The Role model is commonly used in applications to implement role-based access control,
# allowing users to be assigned specific roles and to associate roles with various resources.
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
