# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# A HashList represents a container for managing hash values and their corresponding states or metadata.
# It is associated with a `Project`, a `HashType`, and contains collections of `Campaigns` and `HashItems`.
# == Relationships
#
# - Belongs to a `Project`.
# - Belongs to a `HashType`.
# - Has many `Campaigns` (dependent: destroy).
# - Has many `HashItems` (dependent: destroy).
# - Has one attached `file`.
# == Validations
#
# - `name` must be present, unique (case insensitive), and have a maximum length of 255 characters.
# - `file` must be present when creating a hash list.
# - `separator` must have a length of exactly 1 character (if provided).
# - Custom validation: a file must be attached unless the hash list is already processed.
# == Scopes
#
# - `sensitive`: Fetches hash lists marked as sensitive.
# - `accessible_to(user)`: Retrieves hash lists either not marked as sensitive or associated with projects accessible to the given user.
# - Default scope: Orders hash lists by `created_at`.
# == Delegations
#
# - Delegates the `hash_mode` method to the associated `HashType`.
# == Callbacks
#
# - After save: Triggers hash list processing if a file is attached.
# == Methods
#
# - `completion`: Returns the completion status of the hash list in the format "cracked_count / total_count". If not processed, returns "importing...".
# - `cracked_count`: Retrieves the count of `HashItems` with a non-nil `plain_text`.
# - `cracked_list`: Constructs a string representation of cracked hashes in the format "hash_value:plain_text" using the defined separator.
# - `hash_item_count`: Returns the total count of associated `HashItems`.
# - `uncracked_count`: Retrieves the count of `HashItems` without a non-nil `plain_text`.
# - `uncracked_items`: Returns a collection of `HashItems` that are not cracked.
# - `uncracked_list`: Constructs a string representation of uncracked hashes, with one hash per line.
# - `uncracked_list_checksum`: Calculates and returns the MD5 checksum of the uncracked list as a base64-encoded string.
# == Private Methods
#
# - `file_attached?`: Checks if a file is attached and the hash list is not yet processed.
# - `file_must_be_attached`: Adds a validation error if the file is not attached or processed.
# - `process_hash_list`: Processes the hash list asynchronously using a background job (or performs it immediately in the test environment).
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
