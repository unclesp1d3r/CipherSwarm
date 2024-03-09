# == Schema Information
#
# Table name: operating_systems
#
#  id                                                     :bigint           not null, primary key
#  cracker_command(Command to run the cracker on this OS) :string
#  name(Name of the operating system)                     :string           indexed
#  created_at                                             :datetime         not null
#  updated_at                                             :datetime         not null
#
# Indexes
#
#  index_operating_systems_on_name  (name)
#
require 'rails_helper'

RSpec.describe OperatingSystem, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
