# frozen_string_literal: true

# == Schema Information
#
# Table name: campaigns
#
#  id            :bigint           not null, primary key
#  attacks_count :integer          default(0), not null
#  description   :text
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  hash_list_id  :bigint           not null, indexed
#  project_id    :bigint           not null, indexed
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
FactoryBot.define do
  factory :campaign do
    name
    hash_list
    project { Project.first || create(:project) }
  end
end
