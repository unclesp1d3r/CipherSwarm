# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Manages cracker binary files and their compatibility with operating systems.
#
# @relationships
# - has_and_belongs_to_many :operating_systems
# - has_one_attached :archive_file (7zip format)
#
# @validations
# - version: present, semantic version format (x.y.z)
# - archive_file: present, 7z content type
# - operating_systems: at least one required
#
# @methods
# - semantic_version: returns SemVersion instance
# - set_semantic_version: parses version string into components
#
# Class representing the CrackerBinary model.
#
# CrackerBinary primarily deals with metadata about a cracker binary file, such as its
# semantic version, associated operating systems, and attached archive file. It includes
# validations for its fields and provides methods for version manipulation and comparison.
#
# Associations:
# - `operating_systems`: A many-to-many association indicating the operating systems
#   that the cracker binary supports.
# - `archive_file`: An attached file representing the cracker binary's archive. It is stored
#   and managed as a 7zip file.
#
# Validations:
# - `version`: Must be present and adhere to the semantic versioning format, enforced by
#   a custom `VersionValidator`.
# - `archive_file`: Must be attached, non-empty, and of type "application/x-7z-compressed".
# - `operating_systems`: Must be present and include at least one operating system.
#
# Instance Methods:
# - `semantic_version`: Returns the represented semantic version object for this instance.
# - `set_semantic_version`: Parses and assigns semantic version components to attributes.
# - `version=`: Validates and sets a new version, including handling `v` prefixes.
#
# Class Methods:
# - `check_for_newer`: Finds newer versions of a cracker binary for a given operating system.
# - `latest_versions`: Retrieves the latest versions of cracker binaries for a specific
#   operating system, ordered by creation date.
# - `to_semantic_version`: Converts a version string into a semantic version object.
# - `version_regex`: Returns the regular expression for matching valid version strings.
# == Schema Information
#
# Table name: cracker_binaries
#
#  id                                                                :bigint           not null, primary key
#  active(Is the cracker binary active?)                             :boolean          default(TRUE), not null
#  major_version(The major version of the cracker binary.)           :integer
#  minor_version(The minor version of the cracker binary.)           :integer
#  patch_version(The patch version of the cracker binary.)           :integer
#  prerelease_version(The prerelease version of the cracker binary.) :string           default("")
#  version(Version of the cracker binary, e.g. 6.0.0 or 6.0.0-rc1)   :string           not null, indexed
#  created_at                                                        :datetime         not null
#  updated_at                                                        :datetime         not null
#
# Indexes
#
#  index_cracker_binaries_on_version  (version)
#
class CrackerBinary < ApplicationRecord
  has_and_belongs_to_many :operating_systems # The operating systems that the cracker binary supports.
  has_one_attached :archive_file, dependent: :destroy # The archive file containing the cracker binary. Should be a 7zip file.

  validates :version, presence: true
  validates_with VersionValidator # Validates the version format is a semantic version. (e.g. 1.2.3)
  validates :archive_file, attached: true,
                           content_type: "application/x-7z-compressed"
  validates :operating_systems, presence: true

  # Returns the semantic version of the cracker binary.
  #
  # The semantic version is represented by an instance of the SemVersion class,
  # which encapsulates the major version, minor version, patch version, and prerelease version.
  #
  # @return [SemVersion] The semantic version of the cracker binary.
  def semantic_version
    SemVersion.new([major_version, minor_version, patch_version, prerelease_version])
  end

  # Sets the semantic version components based on the given version string.
  #
  # Parameters:
  # - version: A string representing the semantic version.
  #
  # Returns: None
  def set_semantic_version
    sem = SemVersion.new(version)
    self.major_version = sem.major
    self.minor_version = sem.minor
    self.patch_version = sem.patch
    self.prerelease_version = sem.prerelease
  end

  # Sets the version attribute after validating and formatting the input value.
  # If the value starts with "v", it removes the "v" prefix.
  # Validates the version using SemVersion. If invalid, adds an error to the version attribute.
  # If valid, sets the version attribute and updates the semantic version.
  #
  # @param value [String] the version string to be set
  # @return [void]
  def version=(value)
    value = value.delete("v") if value.start_with?("v")

    unless SemVersion.valid?(value)
      errors.add(:version, "is not a valid version")
      return
    end

    super(value)
    set_semantic_version
  end

  class << self
    # Public: Checks for a newer version of a cracker binary for a given operating system.
    #
    # operating_system_name - The name of the operating system (String).
    # version_string - The version string of the current cracker binary (String).
    #
    # Returns the latest version of the cracker binary that is greater than the current version, or nil if no newer version is found.
    def check_for_newer(operating_system_name, version_string)
      # Convert the version string to a semantic version.
      sem_version = CrackerBinary.to_semantic_version(version_string)

      # Return nil if the version string is invalid.
      return nil if sem_version.nil?

      # Find the latest version that is greater than or equal to the current version.
      major_match = latest_versions(operating_system_name)
        .where(major_version: sem_version.major..)
      # If there are no major versions that are greater than or equal to the current version, return nil.
      return nil if major_match.empty?

      minor_match = major_match.where(minor_version: sem_version.minor..)
      # If there are no minor versions that are greater than or equal to the current version, return nil.
      return nil if minor_match.empty?
      # If there are minor versions that are greater than the current version, return the latest one.
      return minor_match.first if minor_match.first.minor_version > sem_version.minor

      patch_match = minor_match.where(patch_version: sem_version.patch..)
      # If there are no patch versions that are greater than or equal to the current version, return nil.
      return nil if patch_match.empty?
      # If there are patch versions that are greater than the current version (where the major and minor match), return the latest one.
      return patch_match.first if patch_match.first.patch_version > sem_version.patch

      # Check for any prerelease versions that are greater than or equal to the current version, where the major, minor, and patch match.
      latest = patch_match.where("prerelease_version >= ? OR prerelease_version IS NULL", sem_version.prerelease)
                          .order(created_at: :desc).first

      # Return nil if no latest version is found.
      return nil if latest.nil?

      # If everything matches, return the latest version.
      # Return the latest version if it is greater than the current version. Otherwise, return nil.
      latest.semantic_version > sem_version ? latest : nil
    end

    # Returns the latest versions of cracker binaries for a specific operating system.
    #
    # @param operating_system_name [String] The name of the operating system.
    # @return [ActiveRecord::Relation] A collection of cracker binaries ordered by creation date in descending order.
    def latest_versions(operating_system_name)
      CrackerBinary.includes(:operating_systems)
                   .where(operating_systems: { name: operating_system_name }).order(created_at: :desc)
    end

    # Converts a version string to a semantic version object.
    #
    # Parameters:
    # - ver: A string representing the version.
    #
    # Returns:
    # - A semantic version object if the input is a valid version string, otherwise nil.
    def to_semantic_version(ver)
      return ver unless ver.is_a? String

      ver = ver.delete("v") if ver.start_with?("v")
      return nil unless SemVersion.valid?(ver)

      SemVersion.from_loose_version(ver)
    end

    # Returns a regular expression pattern for matching version numbers.
    #
    # The pattern matches version numbers in the format:
    #   - Major.Minor.Patch-PreRelease+BuildMetadata
    #
    # Examples:
    #   - 1.0.0
    #   - 2.3.1-alpha.1+build.123
    #
    # Returns:
    #   - A regular expression pattern for matching version numbers.
    def version_regex
      /^(\d+)(?:\.(\d+)(?:\.(\d+)(?:-([\dA-Za-z\-]+(?:\.[\dA-Za-z\-]+)*))?(?:\+([\dA-Za-z\-]+(?:\.[\dA-Za-z\-]+)*))?)?)?$/
    end
  end
end
