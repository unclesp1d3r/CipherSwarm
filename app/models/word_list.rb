# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Represents a word list in the application.
#
# == Description
# The WordList class is used to define the structure and behavior of a word list resource within the application.
# It inherits from ApplicationRecord and includes the AttackResource module, which provides shared functionality
# for resources related to attack configurations.
#
# This model supports attaching a file, associating the word list with multiple projects, and tracking the
# creator of the list. In addition, it offers features such as validation of attributes, calculating resource
# complexity, and handling sensitive word lists.
#
# == Attributes
# - name: The name of the word list. Must be unique, present, and has a maximum length of 255 characters.
# - description: Describes the purpose or content of the word list.
# - file: An attached file containing the content of the word list. Must be present and of valid content type.
# - line_count: The number of lines in the file. Must be a non-negative integer if provided.
# - sensitive: A boolean indicating whether the word list contains sensitive content. Must be explicitly set.
# - processed: A boolean indicating whether the word list has been processed. Defaults to false.
# - creator_id: The ID of the user who created the word list.
# - created_at: A timestamp indicating when the word list was created.
# - updated_at: A timestamp indicating when the word list was last updated.
#
# == Associations
# - Belongs to a creator (User model).
# - Has one attached file.
# - Has and belongs to many projects.
# - Has many associated attacks.
#
# == Validations
# - Validates the presence and uniqueness (case insensitive) of the `name` attribute.
# - Validates the attachment of a file and its content type.
# - Validates numericality of `line_count` when provided.
# - Validates the presence of associated projects when the list is marked as sensitive.
# - Validates that `sensitive` is always explicitly defined as true or false.
#
# == Scopes
# - `sensitive`: Retrieves word lists marked as sensitive.
# - `shared`: Retrieves word lists not marked as sensitive.
#
# == Callbacks
# - After commit, updates the line count of the word list if a file is attached.
#
# == Delegations
# - Delegates the `attached?` method to the associated file with the prefix `file`.
#
# == Class Responsibilities
# The WordList class is responsible for:
# - Managing the attributes and relationships of word list records.
# - Validating that the data associated with a word list meets the required criteria.
# - Providing scopes for querying word lists based on their sensitivity.
# - Handling actions such as updating line counts and calculating complexities.
#
# See Also:
# - {AttackResource}[file:attack_resource.rb]
# - {WordListsController}[controller:word_lists_controller.rb]
# - {Project}[model:project.rb]
# == Schema Information
#
# Table name: word_lists
#
#  id                                           :bigint           not null, primary key
#  description(Description of the word list)    :text
#  line_count(Number of lines in the word list) :bigint
#  name(Name of the word list)                  :string           not null, uniquely indexed
#  processed                                    :boolean          default(FALSE), not null, indexed
#  sensitive(Is the word list sensitive?)       :boolean          not null
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#  creator_id(The user who created this list)   :bigint           indexed
#
# Indexes
#
#  index_word_lists_on_creator_id  (creator_id)
#  index_word_lists_on_name        (name) UNIQUE
#  index_word_lists_on_processed   (processed)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#
class WordList < ApplicationRecord
  include AttackResource
end
