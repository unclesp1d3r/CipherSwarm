# frozen_string_literal: true

# == Schema Information
#
# Table name: word_lists
#
#  id                                           :bigint           not null, primary key
#  description(Description of the word list)    :text
#  line_count(Number of lines in the word list) :integer
#  name(Name of the word list)                  :string           indexed
#  processed                                    :boolean          default(FALSE), indexed
#  sensitive(Is the word list sensitive?)       :boolean
#  created_at                                   :datetime         not null
#  updated_at                                   :datetime         not null
#
# Indexes
#
#  index_word_lists_on_name       (name) UNIQUE
#  index_word_lists_on_processed  (processed)
#
class WordList < ApplicationRecord
  has_one_attached :file
  has_and_belongs_to_many :projects
  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }
  validates :file, attached: true, content_type: %i[text/plain]
  validates :line_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  has_and_belongs_to_many :attacks
  validates :projects, presence: { message: "must be selected for sensitive word lists" }, if: -> { sensitive? }

  scope :sensitive, -> { where(sensitive: true) }

  after_save :update_line_count, if: :file_attached?
  broadcasts_refreshes unless Rails.env.test?

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
    if Rails.env.test?
      CountFileLinesJob.perform_now(id, "WordList")
      return
    end
    CountFileLinesJob.perform_later(id, "WordList")
  end

  private

  # Checks if a file is attached to the WordList object.
  #
  # Returns:
  # - true if a file is attached
  # - false if no file is attached
  def file_attached?
    file.attached?
  end
end
