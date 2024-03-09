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
require 'rails_helper'

RSpec.describe CrackerBinary, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
