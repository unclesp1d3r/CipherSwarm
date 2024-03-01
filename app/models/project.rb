# == Schema Information
#
# Table name: projects
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_projects_on_name  (name) UNIQUE
#
class Project < ApplicationRecord
  validates_presence_of :name
  has_many :project_users, dependent: :destroy
  has_many :users, through: :project_users
end
