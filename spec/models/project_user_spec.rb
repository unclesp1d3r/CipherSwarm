# == Schema Information
#
# Table name: project_users
#
#  id                                         :bigint           not null, primary key
#  role(The role of the user in the project.) :integer          default("viewer"), not null
#  created_at                                 :datetime         not null
#  updated_at                                 :datetime         not null
#  project_id                                 :bigint           not null, indexed
#  user_id                                    :bigint           not null, indexed
#
# Indexes
#
#  index_project_users_on_project_id  (project_id)
#  index_project_users_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
require 'rails_helper'

RSpec.describe ProjectUser, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:project) }
  it { is_expected.to validate_presence_of(:project) }
  it { is_expected.to validate_presence_of(:user) }
  it { is_expected.to define_enum_for(:role).with_values(viewer: 0, editor: 1, contributor: 2, admin: 3, owner: 4) }
end
