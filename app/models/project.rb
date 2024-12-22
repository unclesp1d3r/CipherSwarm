# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# A class representing a Project entity in the application.
#
# The Project class serves as a primary unit of organization, allowing for
# management and association of related entities such as users, campaigns,
# and various list resources. This class includes capabilities for auditing,
# resource assignment, and refresh broadcasts for updates.
#
# === Validations
# * +name+ - Must be present, unique (case-insensitive), and at most 100 characters long.
#
# === Associations
# * +has_many+ - project_users (dependent: destroy)
# * +has_many+ - hash_lists (dependent: destroy)
# * +has_many+ - users (through project_users)
# * +has_many+ - campaigns (dependent: destroy)
# * +has_and_belongs_to_many+ - word_lists
# * +has_and_belongs_to_many+ - rule_lists
# * +has_and_belongs_to_many+ - mask_lists
# * +has_and_belongs_to_many+ - agents
#
# === Scopes
# * Default scope - Orders projects by creation date.
#
# === Callbacks and Behavior
# * Audited unless in a test environment.
# * Broadcasts refresh updates (via Turbo Streams) unless in a test environment.
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
