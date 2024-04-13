# frozen_string_literal: true

class AddHabtmProjectsToWordList < ActiveRecord::Migration[7.1]
  def change
    create_join_table :projects, :word_lists do |t|
      t.index %i[project_id word_list_id], name: "index_projects_word_lists_on_project_id_and_word_list_id"
      t.index %i[word_list_id project_id], name: "index_projects_word_lists_on_word_list_id_and_project_id"
    end
    remove_column :word_lists, :project_id, :bigint
  end
end
