# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The ProjectUser model represents the association between a user and a project.
# It includes auditing capabilities (except in the test environment) and defines
# relationships to the User and Project models. The role attribute is validated
# for presence and is enumerated with the following possible values:
#
# - viewer (0): Can view the project, but not make changes.
# - editor (1): Can view and edit the project, but not add or remove users or delete the project.
#               Can also trigger tasks and view results.
# - contributor (2): Can view, edit, and add or remove users, but not delete the project.
#                    Can also add or remove agents and tasks.
# - admin (3): Can view, edit, and add or remove users, but not delete the project.
# - owner (4): Can do anything, including delete the project.
#
# The default role is set to :viewer.
# == Schema Information
#
# Table name: project_users
#
#  id                                         :bigint           not null, primary key
#  role(The role of the user in the project.) :integer          default("viewer"), not null
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  project_id                                 :bigint           not null, indexed
#  user_id                                    :bigint           not null, indexed
#
# Indexes
#
#  index_project_users_on_project_id  (project_id)
#  index_project_users_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
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
