# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# The HashList class represents a list of hash items associated with a project.
# It includes various validations, associations, and methods for processing and
# retrieving information about the hash items.
#
# Associations:
# - has_one_attached :file
# - belongs_to :project, touch: true
# - has_many :campaigns, dependent: :destroy
# - has_many :hash_items, dependent: :destroy
# - belongs_to :hash_type
#
# Validations:
# - Validates presence of :name
# - Validates uniqueness of :name (case insensitive)
# - Validates presence of :file on create
# - Validates length of :name (maximum 255 characters)
# - Validates length of :separator (exactly 1 character, allow blank)
# - Validates attachment of :file based on processed status
#
# Scopes:
# - sensitive: Returns hash lists marked as sensitive
# - accessible_to(user): Returns hash lists accessible to the given user
#
# Callbacks:
# - after_save :process_hash_list, if: :file_attached?
#
# Methods:
# - completion: Returns the completion status of the hash list
# - cracked_count: Returns the count of cracked hash items
# - cracked_list: Returns a string representation of the cracked hash list
# - hash_item_count: Returns the count of hash items in the hash list
# - hash_mode: Returns the hashcat mode of the hash type
# - uncracked_count: Returns the count of uncracked hash items
# - uncracked_items: Returns an ActiveRecord relation of uncracked hash items
# - uncracked_list: Returns a string representation of the uncracked hash list
# - uncracked_list_checksum: Calculates the MD5 checksum of the uncracked_list
#
# Private Methods:
# - file_attached?: Checks if a file is attached and not yet processed
# - process_hash_list: Processes the hash list (synchronously in test environment, asynchronously otherwise)
#
# == Schema Information
#
# Table name: hash_lists
#
#  id                                                                                                                        :bigint           not null, primary key
#  description(Description of the hash list)                                                                                 :text
#  hash_items_count                                                                                                          :integer          default(0)
#  name(Name of the hash list)                                                                                               :string           not null, indexed
#  processed(Is the hash list processed into hash items?)                                                                    :boolean          default(FALSE), not null
#  sensitive(Is the hash list sensitive?)                                                                                    :boolean          default(FALSE), not null
#  separator(Separator used in the hash list file to separate the hash from the password or other metadata. Default is ":".) :string(1)        default(":"), not null
#  created_at                                                                                                                :datetime         not null
#  updated_at                                                                                                                :datetime         not null
#  hash_type_id                                                                                                              :bigint           not null, indexed
#  project_id(Project that the hash list belongs to)                                                                         :bigint           not null, indexed
#
# Indexes
#
#  index_hash_lists_on_hash_type_id  (hash_type_id)
#  index_hash_lists_on_name          (name) UNIQUE
#  index_hash_lists_on_project_id    (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (hash_type_id => hash_types.id)
#  fk_rails_...  (project_id => projects.id)
#
class HashList < ApplicationRecord
  has_one_attached :file
  belongs_to :project, touch: true
  has_many :campaigns, dependent: :destroy
  has_many :hash_items, dependent: :destroy
  belongs_to :hash_type

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :file, presence: { on: :create }
  validates :name, length: { maximum: 255 }
  validates :separator, length: { is: 1, allow_blank: true }
  validate :file_must_be_attached

  broadcasts_refreshes unless Rails.env.test?

  scope :sensitive, -> { where(sensitive: true) }
  # create a scope for hash lists that are either not sensitive or are in a project that the user has access to
  scope :accessible_to, ->(user) { where(project_id: user.projects) }

  default_scope { order(:created_at) }

  delegate :hash_mode, to: :hash_type

  after_save :process_hash_list, if: :file_attached?

  # Returns a string representing the completion status of the hash list.
  #
  # The completion status is calculated by dividing the number of cracked items
  # by the total number of hash items in the list.
  #
  # @return [String] The completion status in the format "cracked_count / total_count".
  def completion
    return "importing..." unless processed?

    "#{cracked_count} / #{hash_item_count}"
  end

  # Returns the count of hash items that have been cracked (i.e., their plain_text is not nil).
  # @return [Integer]
  def cracked_count
    Rails.cache.fetch("#{cache_key_with_version}/cracked_count", expires_in: 20.minutes) do
      hash_items.where.not(plain_text: nil).size
    end
  end

  # Returns a string representation of the cracked hash list.
  #
  # This method retrieves the hash items from the database that have been cracked,
  # and constructs a string representation of each hash item in the format: "hash_value:plain_text".
  #
  # Example:
  #   hash_list.cracked_list
  #   # => "hash1:plain_text1\nhash2:plain_text2\n..."
  #
  # Returns:
  #   A string representation of the cracked hash list.
  # @return [String]
  def cracked_list
    # This should output as "hash:plain_text" for each item if the separator is set to ":"
    hash = hash_items.where.not(plain_text: nil).pluck(:hash_value, :plain_text)
    hash.map { |h, p| "#{h}#{separator}#{p}" }.join("\n")
  end

  # Returns the count of items in the hash.
  #
  # @return [Integer] the number of items in the hash
  def hash_item_count
    hash_items.size
  end

  # Returns the count of uncracked hash items.
  #
  # @return [Integer] the number of uncracked hash items
  def uncracked_count
    hash_items.uncracked.size
  end

  # Returns a collection of hash items that are uncracked.
  #
  # @return [ActiveRecord::Relation] a collection of uncracked hash items
  def uncracked_items
    hash_items.uncracked
  end

  # Returns a string representation of the uncracked hash list.
  #
  # This method retrieves the hash items from the database that have not been cracked,
  # and constructs a string representation of each hash item in the format: "hash_value".
  #
  # Example:
  #   hash_list.uncracked_list
  #   # => "hash1\nhash2\n..."
  #
  # Returns:
  #   A string representation of the uncracked hash list.
  # @return [String]
  def uncracked_list
    # This should output as "hash" for each item
    hash_lines = []
    hash = uncracked_items.pluck(:hash_value)
    hash.each do |h|
      hash_lines << "#{h}"
    end
    hash_lines.join("\n")
  end

  # Calculates the MD5 checksum of the uncracked_list.
  #
  # This method calculates the MD5 checksum of the uncracked_list string and returns it as a base64-encoded string.
  #
  # @return [String] The MD5 checksum of the uncracked_list as a base64-encoded string.
  def uncracked_list_checksum
    md5 = OpenSSL::Digest.new("MD5")
    md5.update(uncracked_list)
    md5.base64digest
  end

  # Generates data for JtR/hashcat pot file format.
  #
  # This method retrieves the cracked hash items from the database and constructs
  # a string representation of each hash item in the format: "hash_value:plain_text".
  #
  # @return [String] A string representation of the cracked hash list in JtR/hashcat pot file format.
  def generate_pot_file_data
    cracked_items = hash_items.cracked.pluck(:hash_value, :plain_text)
    cracked_items.map { |h, p| "#{h}#{separator}#{p}" }.join("\n")
  end

  # Generates data for CSV file format including metadata.
  #
  # This method retrieves the cracked hash items from the database and constructs
  # a CSV string representation of each hash item including metadata (machine_name and user_name).
  #
  # @return [String] A CSV string representation of the cracked hash list including metadata.
  def generate_csv_file_data
    CSV.generate(headers: true) do |csv|
      csv << %w[hash_value plain_text machine_name user_name]
      hash_items.cracked.find_each do |item|
        csv << [item.hash_value, item.plain_text, item.metadata["machine_name"], item.metadata["user_name"]]
      end
    end
  end

  private

  # Checks if a file is attached and not processed.
  #
  # @return [Boolean] true if a file is attached and not processed, false otherwise.
  def file_attached?
    file.attached? && !processed?
  end

  def file_must_be_attached
    errors.add(:file, "must be attached") unless processed? || file.attached?
  end

  # Processes the hash list.
  #
  # If the current environment is test, the `ProcessHashListJob` is performed immediately.
  # Otherwise, the `ProcessHashListJob` is performed asynchronously.
  #
  # @return [void]
  def process_hash_list
    if Rails.env.test?
      ProcessHashListJob.perform_now(id)
      return
    end
    ProcessHashListJob.perform_later(id)
  end
end
