# == Schema Information
#
# Table name: campaigns
#
#  id           :bigint           not null, primary key
#  name         :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  hash_list_id :bigint           not null, indexed
#  project_id   :bigint           indexed
#
# Indexes
#
#  index_campaigns_on_hash_list_id  (hash_list_id)
#  index_campaigns_on_project_id    (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (hash_list_id => hash_lists.id)
#  fk_rails_...  (project_id => projects.id)
#
require 'rails_helper'

RSpec.describe Campaign, type: :model do
  it "valid with a name, hash_list, and project" do
    campaign = create(:campaign)
    expect(campaign).to be_valid
  end

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to belong_to(:hash_list) }
  it { is_expected.to belong_to(:project) }
end
