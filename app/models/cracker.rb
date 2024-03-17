# == Schema Information
#
# Table name: crackers
#
#  id                        :bigint           not null, primary key
#  name(Name of the cracker) :string           indexed
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_crackers_on_name  (name) UNIQUE
#
class Cracker < ApplicationRecord
  validates :name, presence: true
  has_many :cracker_binaries, dependent: :destroy
  audited

  def latest_versions(operating_system_name)
    cracker_binaries.includes(:operating_systems).
      where(operating_systems: { name: operating_system_name }).order(created_at: :desc)
  end

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
end
