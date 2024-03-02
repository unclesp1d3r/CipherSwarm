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
  it "is valid with valid attributes" do
    project = create(:project)

    expect(project).to be_valid
  end

  it "is not valid without a name" do
    project = build(:project, name: nil)

    expect(project).to_not be_valid
  end

  it "is not valid without a unique name" do
    project = create(:project)
    project2 = build(:project, name: project.name)

    expect(project2).to_not be_valid
  end

  it "has creates a project_user when a user is added" do
    project = create(:project)
    user = create(:user)
    project.users << user

    expect(project.project_users.count).to eq(1)
    expect(user.projects.count).to eq(1)
  end
end
