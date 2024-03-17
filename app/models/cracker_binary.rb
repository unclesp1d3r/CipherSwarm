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
#  version(Version of the cracker binary, e.g. 6.0.0 or 6.0.0-rc1)   :string           not null, indexed => [cracker_id]
#  created_at                                                        :datetime         not null
#  updated_at                                                        :datetime         not null
#  cracker_id                                                        :bigint           not null, indexed, indexed => [version]
#
# Indexes
#
#  index_cracker_binaries_on_cracker_id              (cracker_id)
#  index_cracker_binaries_on_version_and_cracker_id  (version,cracker_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cracker_id => crackers.id)
#
class CrackerBinary < ApplicationRecord
  audited
  belongs_to :cracker
  has_and_belongs_to_many :operating_systems # The operating systems that the cracker binary supports.
  has_one_attached :archive_file, dependent: :destroy # The archive file containing the cracker binary. Should be a 7zip file.

  validates :version, presence: true,
            uniqueness: { scope: :cracker_id, case_sensitive: false }
  validates_with VersionValidator # Validates the version format is a semantic version. (e.g. 1.2.3)
  validates :archive_file, attached: true,
            content_type: "application/x-7z-compressed"

  def version=(value)
    value = value.gsub("v", "") if value.start_with?("v")
    super(value)
    set_semantic_version
  end

  def set_semantic_version
    sem = SemVersion.new(version)
    self.major_version = sem.major
    self.minor_version = sem.minor
    self.patch_version = sem.patch
    self.prerelease_version = sem.prerelease
  end

  def semantic_version
    SemVersion.new([ self.major_version, self.minor_version, self.patch_version, self.prerelease_version ])
  end

  class << self
    def to_semantic_version(ver)
      return ver unless ver.is_a? String

      ver = ver.gsub("v", "") if ver.start_with?("v")
      return nil unless SemVersion.valid?(ver)
      SemVersion.from_loose_version(ver)
    end
  end
end
