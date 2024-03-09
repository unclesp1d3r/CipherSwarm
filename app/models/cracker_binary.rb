# == Schema Information
#
# Table name: cracker_binaries
#
#  id         :bigint           not null, primary key
#  active     :boolean
#  version    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cracker_id :bigint           not null, indexed
#
# Indexes
#
#  index_cracker_binaries_on_cracker_id  (cracker_id)
#
# Foreign Keys
#
#  fk_rails_...  (cracker_id => crackers.id)
#
class CrackerBinary < ApplicationRecord
  belongs_to :cracker
  has_and_belongs_to_many :operating_systems # The operating systems that the cracker binary supports.
  has_one_attached :archive_file, dependent: :destroy # The archive file containing the cracker binary. Should be a 7zip file.

  validates :version, presence: true,
            uniqueness: { scope: :name, case_sensitive: false }
  validates_with VersionValidator # Validates the version format is a semantic version. (e.g. 1.2.3)
  validates :archive_file, presence: true

  # Returns a SemVersion object representing the semantic version of the cracker binary.
  def semantic_version
    SemVersion.new(version)
  end
end
