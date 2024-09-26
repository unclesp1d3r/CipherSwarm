# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# == Schema Information
#
# Table name: campaigns
#
#  id                                                                                                     :bigint           not null, primary key
#  attacks_count                                                                                          :integer          default(0), not null
#  deleted_at                                                                                             :datetime         indexed
#  description                                                                                            :text
#  name                                                                                                   :string           not null
#  priority( -1: Deferred, 0: Routine, 1: Priority, 2: Urgent, 3: Immediate, 4: Flash, 5: Flash Override) :integer          default("routine"), not null
#  created_at                                                                                             :datetime         not null
#  updated_at                                                                                             :datetime         not null
#  hash_list_id                                                                                           :bigint           not null, indexed
#  project_id                                                                                             :bigint           not null, indexed
#
# Indexes
#
#  index_campaigns_on_deleted_at    (deleted_at)
#  index_campaigns_on_hash_list_id  (hash_list_id)
#  index_campaigns_on_project_id    (project_id)
#
# Foreign Keys
#
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
