# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: campaigns
#
#  id                                             :bigint           not null, primary key
#  attacks_count                                  :integer          default(0), not null
#  deleted_at                                     :datetime         indexed
#  description                                    :text
#  name                                           :string           not null
#  priority(-1: Deferred, 0: Normal, 2: High)     :integer          default("normal"), not null, indexed, indexed => [project_id]
#  created_at                                     :datetime         not null
#  updated_at                                     :datetime         not null
#  creator_id(The user who created this campaign) :bigint           indexed
#  hash_list_id                                   :bigint           not null, indexed
#  project_id                                     :bigint           not null, indexed, indexed => [priority]
#
# Indexes
#
#  index_campaigns_on_creator_id               (creator_id)
#  index_campaigns_on_deleted_at               (deleted_at)
#  index_campaigns_on_hash_list_id             (hash_list_id)
#  index_campaigns_on_priority                 (priority)
#  index_campaigns_on_project_id               (project_id)
#  index_campaigns_on_project_id_and_priority  (project_id,priority)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (hash_list_id => hash_lists.id) ON DELETE => cascade
#  fk_rails_...  (project_id => projects.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :campaign do
    name
    hash_list
    project { Project.first || create(:project) }
  end
end
