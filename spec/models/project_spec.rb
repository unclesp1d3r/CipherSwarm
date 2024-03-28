# == Schema Information
#
# Table name: projects
#
#  id                                      :bigint           not null, primary key
#  description(Description of the project) :text
#  name(Name of the project)               :string(100)      not null, indexed
#  created_at                              :datetime         not null
#  updated_at                              :datetime         not null
#
# Indexes
#
#  index_projects_on_name  (name) UNIQUE
#
require 'rails_helper'

RSpec.describe Project, type: :model do
  subject { build(:project) }
  context 'factory' do
    it { should be_valid }
  end
  context 'database' do
    it { should have_db_column(:name).of_type(:string).with_options(null: false) }
    it { should have_db_column(:description).of_type(:text) }
    it { should have_db_index(:name).unique(true) }
  end
  context 'associations' do
    it { should have_many(:project_users).dependent(:destroy) }
    it { should have_many(:users).through(:project_users) }
  end
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
  end
end
