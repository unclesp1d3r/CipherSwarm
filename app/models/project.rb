# frozen_string_literal: true

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
class Project < ApplicationRecord
  audited unless Rails.env.test?
  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { case_sensitive: false }
  has_many :project_users, dependent: :destroy
  has_many :hash_lists, dependent: :destroy
  has_many :users, through: :project_users
  has_many :campaigns, dependent: :destroy
  has_and_belongs_to_many :word_lists
  has_and_belongs_to_many :rule_lists
  has_and_belongs_to_many :mask_lists
  has_and_belongs_to_many :agents
  broadcasts_refreshes unless Rails.env.test?
end
