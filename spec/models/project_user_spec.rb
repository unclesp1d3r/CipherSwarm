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
  pending "add some examples to (or delete) #{__FILE__}"
end
