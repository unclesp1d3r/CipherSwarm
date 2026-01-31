# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Organizes hash cracking activities and resources into logical groups.
#
# @acts_as
# - resourcify: enables role-based access
# - audited: tracks changes (except in test env)
#
# @relationships
# - has_many :project_users, :users (through project_users)
# - has_many :hash_lists, :campaigns (dependent: destroy)
# - has_and_belongs_to_many :word_lists, :rule_lists, :mask_lists, :agents
#
# @validations
# - name: present, unique (case insensitive), max 100 chars
#
# @scopes
# - default: ordered by created_at
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
#
# == Schema Information
#
# Table name: projects
#
#  id                                      :bigint           not null, primary key
#  description(Description of the project) :text
#  name(Name of the project)               :string(100)      not null, uniquely indexed
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

  include SafeBroadcasting

  broadcasts_refreshes

  default_scope { order(:created_at) }
end
