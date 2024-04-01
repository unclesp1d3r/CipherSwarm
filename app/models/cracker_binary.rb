# == Schema Information
#
# Table name: cracker_binaries
#
#  id                                                                :bigint           not null, primary key
#  active(Is the cracker binary active?)                             :boolean          default(TRUE)
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
  audited unless Rails.env.test?
  has_and_belongs_to_many :operating_systems # The operating systems that the cracker binary supports.
  has_one_attached :archive_file, dependent: :destroy # The archive file containing the cracker binary. Should be a 7zip file.

  validates :version, presence: true
  validates_with VersionValidator # Validates the version format is a semantic version. (e.g. 1.2.3)
  validates :archive_file, attached: true,
            content_type: "application/x-7z-compressed"
  validates :operating_systems, presence: true

  def version=(value)
    value = value.gsub("v", "") if value.start_with?("v")

    unless SemVersion.valid?(value)
      errors.add(:version, "is not a valid version")
      return
    end

    super(value)
    set_semantic_version
  end

  # Sets the semantic version of the cracker binary based on the provided version string.
  #
  # Parameters:
  # - version: A string representing the version of the cracker binary.
  #
  # Returns: None
  def set_semantic_version
    sem = SemVersion.new(version)
    self.major_version = sem.major
    self.minor_version = sem.minor
    self.patch_version = sem.patch
    self.prerelease_version = sem.prerelease
  end

  # Returns the semantic version of the cracker binary.
  #
  # The semantic version consists of the major version, minor version, patch version,
  # and prerelease version. It is represented as an instance of the SemVersion class.
  #
  # @return [SemVersion] The semantic version of the cracker binary.
  def semantic_version
    SemVersion.new([ self.major_version, self.minor_version, self.patch_version, self.prerelease_version ])
  end

  class << self
    # Returns the latest versions of cracker binaries for a specific operating system.
    #
    # @param operating_system_name [String] The name of the operating system.
    # @return [ActiveRecord::Relation] A relation containing the latest versions of cracker binaries.
    def latest_versions(operating_system_name)
      CrackerBinary.includes(:operating_systems).
        where(operating_systems: { name: operating_system_name }).order(created_at: :desc)
    end

    # Determines if there is a newer version available for a given operating system and version.
    #
    # @param operating_system_name [String] The name of the operating system.
    # @param version_string [String] The version string to compare against.
    # @return [CrackerBinary, nil] The latest version that is greater than the current version, or nil if no newer version is found.
    def check_for_newer(operating_system_name, version_string)
      # Convert the version string to a semantic version.
      sem_version = CrackerBinary.to_semantic_version(version_string)

      # Return nil if the version string is invalid.
      return nil if sem_version.nil?

      # Find the latest version that is greater than or equal to the current version.
      major_match = self.latest_versions(operating_system_name).
        where("major_version >= ?", sem_version.major)
      # If there are no major versions that are greater than or equal to the current version, return nil.
      return nil if major_match.empty?

      minor_match = major_match.where("minor_version >= ?", sem_version.minor)
      # If there are no minor versions that are greater than or equal to the current version, return nil.
      return nil if minor_match.empty?
      # If there are minor versions that are greater than the current version, return the latest one.
      return minor_match.first if minor_match.first.minor_version > sem_version.minor

      patch_match = minor_match.where("patch_version >= ?", sem_version.patch)
      # If there are no patch versions that are greater than or equal to the current version, return nil.
      return nil if patch_match.empty?
      # If there are patch versions that are greater than the current version (where the major and minor match), return the latest one.
      return patch_match.first if patch_match.first.patch_version > sem_version.patch

      # Check for any prerelease versions that are greater than or equal to the current version, where the major, minor, and patch match.
      latest = patch_match.where("prerelease_version >= ? OR prerelease_version IS NULL", sem_version.prerelease).
        order(created_at: :desc).first

      # Return nil if no latest version is found.
      return nil if latest.nil?

      # If everything matches, return the latest version.
      # Return the latest version if it is greater than the current version. Otherwise, return nil.
      latest.semantic_version > sem_version ? latest : nil
    end

    def version_regex
      /^(\d+)(?:\.(\d+)(?:\.(\d+)(?:-([\dA-Za-z\-]+(?:\.[\dA-Za-z\-]+)*))?(?:\+([\dA-Za-z\-]+(?:\.[\dA-Za-z\-]+)*))?)?)?$/
    end

    # Converts a version string to a semantic version object.
    #
    # Parameters:
    # - ver: A version string to be converted.
    #
    # Returns:
    # - A semantic version object if the conversion is successful, or the original version if it's not a string.
    #
    # Example:
    #   to_semantic_version("1.2.3") #=> #<SemVersion:0x00007f8a8a8a8a8a @major=1, @minor=2, @patch=3>
    #
    def to_semantic_version(ver)
      return ver unless ver.is_a? String

      ver = ver.gsub("v", "") if ver.start_with?("v")
      return nil unless SemVersion.valid?(ver)
      SemVersion.from_loose_version(ver)
    end
  end
end
