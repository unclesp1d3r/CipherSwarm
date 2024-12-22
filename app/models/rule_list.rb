# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# A class that represents a collection of rules within the application.
#
# RuleList inherits from the base `ApplicationRecord` class and includes
# the behaviors defined in the `AttackResource` module.
#
# == Relationships
# - Has an attached file, which stores the rule list.
# - Belongs to a creator (an instance of the User class).
# - Has and belongs to many projects.
# - Has many associated attacks, which are destroyed when the rule list is deleted.
#
# == Validations
# - The `name` attribute must be present, unique (case insensitive), and have a maximum length of 255 characters.
# - The attached `file` must be a text file or binary file.
# - The `line_count` attribute must be a non-negative integer (optional).
# - At least one project must be selected for sensitive rule lists.
# - The `sensitive` attribute must be either `true` or `false`.
#
# == Scopes
# - `sensitive`: Returns rule lists marked as sensitive.
# - `shared`: Returns rule lists not marked as sensitive.
#
# == Callbacks
# - Automatically updates the `line_count` based on the attached file after a commit.
#
# == Delegations
# - Delegates the method `file_attached?` to check if a file is attached.
#
# == Broadcasting
# - Broadcasts updates to the resource unless the application is running in the test environment.
#
# == Default Scope
# - Orders rule lists by their `created_at` timestamp in ascending order.
#
# == Instance Methods
# - `complexity`: Calculates the complexity of the rule list based on either its line count or other attributes, depending on the class type.
# - `complexity_string`: Returns a human-readable string representation of the complexity using SI prefixes.
# - `update_line_count`: Updates the line count of the attached file asynchronously, or immediately if in the test environment.
class RuleList < ApplicationRecord
  include AttackResource
end
