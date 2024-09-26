# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The Project model represents a project within the CipherSwarm application.
# It includes various associations and validations to ensure data integrity.
#
# Associations:
# - has_many :project_users, dependent: :destroy
# - has_many :hash_lists, dependent: :destroy
# - has_many :users, through: :project_users
# - has_many :campaigns, dependent: :destroy
# - has_and_belongs_to_many :word_lists
# - has_and_belongs_to_many :rule_lists
# - has_and_belongs_to_many :mask_lists
# - has_and_belongs_to_many :agents
#
# Validations:
# - Validates presence of :name
# - Validates length of :name (maximum 100 characters)
# - Validates uniqueness of :name (case insensitive)
#
# Scopes:
# - default_scope orders projects by :created_at
#
# Callbacks:
# - audited unless in test environment
# - broadcasts_refreshes unless in test environment
#
# Additional Functionality:
# - resourcify: Adds role-based resource management
# == Schema Information
#
# Table name: projects
#
#  id                                      :bigint           not null, primary key
#  description(Description of the project) :text
#  name(Name of the project)               :string(100)      not null, indexed
#  created_at                              :datetime         not null
#  updated_at                              :datetime         not null
#
# Indexes
#
#  index_projects_on_name  (name) UNIQUE
#
class Project < ApplicationRecord
  resourcify
  audited unless Rails.env.test?
  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }
  has_many :project_users, dependent: :destroy
  has_many :hash_lists, dependent: :destroy
  has_many :users, through: :project_users
  has_many :campaigns, dependent: :destroy
  has_and_belongs_to_many :word_lists
  has_and_belongs_to_many :rule_lists
  has_and_belongs_to_many :mask_lists
  has_and_belongs_to_many :agents
  broadcasts_refreshes unless Rails.env.test?

  default_scope { order(:created_at) }
end
