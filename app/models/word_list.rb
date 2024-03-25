# == Schema Information
#
# Table name: word_lists
#
#  id                                                 :bigint           not null, primary key
#  description(Description of the word list)          :text
#  line_count(Number of lines in the word list)       :integer
#  name(Name of the word list)                        :string           indexed
#  processed                                          :boolean          default(FALSE), indexed
#  sensitive(Is the word list sensitive?)             :boolean
#  created_at                                         :datetime         not null
#  updated_at                                         :datetime         not null
#  project_id(Project to which the word list belongs) :bigint           not null, indexed
#
# Indexes
#
#  index_word_lists_on_name        (name) UNIQUE
#  index_word_lists_on_processed   (processed)
#  index_word_lists_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
class WordList < ApplicationRecord
  has_one_attached :file
  belongs_to :project
  has_and_belongs_to_many :attacks, foreign_key: :word_list_id, join_table: :operations_word_lists
  validates_presence_of :name
  validates_uniqueness_of :name, scope: :project_id
  validates :file, attached: true, content_type: %i[text/plain]

  after_save :update_line_count, if: :file_attached?
  broadcasts_refreshes

  private

  # Checks if a file is attached to the WordList object.
  #
  # Returns:
  # - true if a file is attached
  # - false if no file is attached
  def file_attached?
    file.attached?
  end

  # Updates the line count for the current WordList instance.
  #
  # This method enqueues a background job to perform the line count update
  # asynchronously using the CountFileLinesJob class.
  #
  # Example:
  #   word_list = WordList.find(1)
  #   word_list.update_line_count
  #
  # Returns:
  #   None
  def update_line_count
    CountFileLinesJob.perform_later(id)
  end
end
