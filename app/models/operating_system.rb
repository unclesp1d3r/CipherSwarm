# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The OperatingSystem model represents an operating system that is supported by cracker binaries.
#
# Associations:
# - has_and_belongs_to_many :cracker_binaries: The cracker binaries that support this operating system.
#
# Validations:
# - name: Must be present, unique (case insensitive), and have a maximum length of 255 characters.
# - cracker_command: Must be present, have a maximum length of 255 characters, and not contain any whitespace.
#
# Normalizations:
# - name: Strips leading/trailing whitespace and converts to lowercase.
#
# Instance Methods:
# - to_s: Returns a string representation of the operating system (the name).

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
