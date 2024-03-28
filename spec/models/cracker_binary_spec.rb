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
require 'rails_helper'

RSpec.describe CrackerBinary, type: :model do
  context 'validations' do
    it { should allow_value("6.0.0").for(:version) }
    it { should validate_presence_of(:cracker) }
  end
  context 'associations' do
    it { should belong_to(:cracker) }
    it { should have_one_attached(:archive_file) }
  end
  it 'valid with a version and cracker'
  context "db columns" do
    it { should have_db_index([ :version, :cracker_id ]).unique(true) }
    it { should have_db_column(:active).of_type(:boolean).with_options(default: true) }
    it { should have_db_column(:major_version).of_type(:integer) }
    it { should have_db_column(:minor_version).of_type(:integer) }
    it { should have_db_column(:patch_version).of_type(:integer) }
    it { should have_db_column(:prerelease_version).of_type(:string).with_options(default: "") }
  end
  describe "#to_semantic_version" do
    it "returns the version as is if it's not a string" do
      ver = 6.0
      expect(CrackerBinary.to_semantic_version(ver)).to eq(ver)
    end

    it "removes 'v' prefix if present" do
      ver = "v6.0.0"
      expect(CrackerBinary.to_semantic_version(ver)).to eq(SemVersion.new("6.0.0"))
    end

    it "returns nil if the version is not valid" do
      ver = "invalid_version"
      expect(CrackerBinary.to_semantic_version(ver)).to be_nil
    end

    it "returns a SemVersion object if the version is valid" do
      ver = "6.0.0"
      expect(CrackerBinary.to_semantic_version(ver)).to be_a(SemVersion)
    end
  end
end
