# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The ProjectUser model represents the association between a user and a project,
# defining the user's role within the project. This class includes functionality
# to manage and validate the role assigned to each user in a project.
class ProjectUser < ApplicationRecord
  audited unless Rails.env.test?
  belongs_to :user, touch: true
  belongs_to :project, touch: true
  validates :role, presence: true

  enum :role, {
    # Can view the project, but not make changes
    viewer: 0,
    # Can view and edit the project, but not add or remove users or delete the project
    # Can also trigger tasks and view results.
    editor: 1,
    # Can view, edit, and add or remove users, but not delete the project.
    # Can also add or remove agents and tasks.
    contributor: 2,
    # Can view, edit, and add or remove users, but not delete the project.
    admin: 3,
    # Can do anything, including delete the project
    owner: 4
  }, prefix: false, suffix: false, default: :viewer
end
