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
  belongs_to :cracker, touch: true # The cracker that the cracker binary belongs to.
  has_and_belongs_to_many :operating_systems # The operating systems that the cracker binary supports.
  has_one_attached :archive_file, dependent: :destroy # The archive file containing the cracker binary. Should be a 7zip file.

  validates :version, presence: true,
            uniqueness: { scope: :cracker_id, case_sensitive: false }
  validates_with VersionValidator # Validates the version format is a semantic version. (e.g. 1.2.3)
  validates :archive_file, attached: true,
            content_type: "application/x-7z-compressed"
  validates :cracker, presence: true
  validates :operating_systems, presence: true

  def version=(value)
    value = value.gsub("v", "") if value.start_with?("v")
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
    def version_regex
      /^v?(\d+)(?:\.(\d+)(?:\.(\d+)(?:-([\dA-Za-z\-]+(?:\.[\dA-Za-z\-]+)*))?(?:\+([\dA-Za-z\-]+(?:\.[\dA-Za-z\-]+)*))?)?)?$/ # rubocop:disable Layout/LineLength
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
