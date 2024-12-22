# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Represents an operating system with its associated cracker binaries.
#
# This class allows management and validation of operating system names and
# cracker commands, which are used in the context of cryptanalysis or
# password recovery operations. It also supports normalization of the
# operating system's name for consistency.
#
# Associations:
# - `has_and_belongs_to_many :cracker_binaries`
#   Defines a many-to-many relationship with `CrackerBinary` objects, representing
#   the cracker binaries that can be used with this operating system.
#
# Validations:
# - `:name`
#   Ensures that the `name` of the operating system is present, unique
#   (case-insensitively), and does not exceed a maximum length of 255 characters.
#
# - `:cracker_command`
#   Validates the presence of a valid `cracker_command` string, ensures that it
#   does not exceed a maximum length of 255 characters, and prohibits white spaces.
#
# Normalizations:
# - `:name`
#   Strips leading and trailing whitespace from the `name` and converts it to
#   lowercase.
#
# Instance Methods:
# - `to_s`
#   Returns a titleized version of the operating system's name. This method can
#   be used for display purposes, where a capitalized format of the name is desirable.
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
