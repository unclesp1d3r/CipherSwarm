# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Manages operating system configurations and cracker binary compatibility.
#
# @relationships
# - has_and_belongs_to_many :cracker_binaries
#
# @validations
# - name: present, unique (case insensitive), max 255 chars
# - cracker_command: present, max 255 chars, no whitespace
#
# @normalizations
# - name: stripped and downcased
#
# @methods
# - to_s: returns titleized name
#
# == Schema Information
#
# Table name: operating_systems
#
#  id                                                     :bigint           not null, primary key
#  cracker_command(Command to run the cracker on this OS) :string           not null
#  name(Name of the operating system)                     :string           not null, indexed
#  created_at                                             :datetime         not null
#  updated_at                                             :datetime         not null
#
# Indexes
#
#  index_operating_systems_on_name  (name) UNIQUE
#
class OperatingSystem < ApplicationRecord
  has_and_belongs_to_many :cracker_binaries # The cracker binaries that support this operating system.

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }
  validates :cracker_command, presence: true, length: { maximum: 255 }, format: { without: /\s/ }

  normalizes :name, with: ->(value) { value.strip.downcase }

  # Returns the titleized version of the operating system's name.
  #
  # @return [String] the titleized name of the operating system
  def to_s
    name.titleize
  end
end
