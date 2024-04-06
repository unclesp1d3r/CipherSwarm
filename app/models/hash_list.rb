# frozen_string_literal: true

# == Schema Information
#
# Table name: hash_lists
#
#  id                                                                                                                        :bigint           not null, primary key
#  description(Description of the hash list)                                                                                 :text
#  hash_mode(Hash mode of the hash list (hashcat mode))                                                                      :integer          not null, indexed
#  metadata_fields_count(Number of metadata fields in the hash list file. Default is 0.)                                     :integer          default(0), not null
#  name(Name of the hash list)                                                                                               :string           not null, indexed
#  processed(Is the hash list processed into hash items?)                                                                    :boolean          default(FALSE)
#  salt(Does the hash list contain a salt?)                                                                                  :boolean          default(FALSE)
#  sensitive(Is the hash list sensitive?)                                                                                    :boolean          default(FALSE)
#  separator(Separator used in the hash list file to separate the hash from the password or other metadata. Default is ":".) :string(1)        default(":"), not null
#  created_at                                                                                                                :datetime         not null
#  updated_at                                                                                                                :datetime         not null
#  project_id(Project that the hash list belongs to)                                                                         :bigint           not null, indexed
#
# Indexes
#
#  index_hash_lists_on_hash_mode   (hash_mode)
#  index_hash_lists_on_name        (name) UNIQUE
#  index_hash_lists_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#
class HashList < ApplicationRecord
  audited unless Rails.env.test?
  has_one_attached :file
  belongs_to :project, touch: true
  has_one :campaign, dependent: :destroy
  has_many :hash_items, dependent: :destroy

  validates :name, :hash_mode, presence: true
  validates :name, uniqueness: { case_sensitive: false }
  validates :file, presence: { on: :create }
  validates :name, length: { maximum: 255 }
  validates :separator, length: { is: 1, allow_blank: true }
  validates :metadata_fields_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :file, content_type: %w[text/plain], attached: ->(record) { record.processed? || record.file.attached? }

  broadcasts_refreshes unless Rails.env.test?

  scope :sensitive, -> { where(sensitive: true) }

  after_save :process_hash_list, if: :file_attached?
  enum hash_mode: {
    md5: 0,
    sha1: 100,
    sha256: 1400,
    sha512: 1700,
    ntlm: 1000,
    ntlm_v2: 5600,
    ntlm_v2_unicode: 5700,
    lm: 3000,
    lm_challenge: 5500,
    sha512crypt: 1800,
    md5crypt: 500,
    bcrypt: 3200,
    sha256crypt: 7400
  }

  # Returns a string representing the completion status of the hash list.
  #
  # The completion status is calculated by dividing the number of cracked items
  # by the total number of hash items in the list.
  #
  # @return [String] The completion status in the format "cracked_count / total_count".
  def completion
    "#{cracked_count} / #{hash_items.count}"
  end

  # Returns the count of hash items that have been cracked (i.e., their plain_text is not nil).
  def cracked_count
    hash_items.where.not(plain_text: nil).count
  end



  # Returns a string representation of the cracked hash list.
  #
  # This method retrieves the hash items from the database that have a non-nil plain_text value,
  # and constructs a string representation of each hash item in the format: "salt|hash_value|plain_text".
  # If a hash item has no salt, the salt part is omitted.
  #
  # Example:
  #   hash_list.cracked_list
  #   # => "salt1|hash1|plain_text1\nsalt2|hash2|plain_text2\n..."
  #
  # Returns:
  #   A string representation of the cracked hash list.
  def cracked_list
    hash_lines = []
    hash = hash_items.where.not(plain_text: nil).pluck(%i[hash_value salt plain_text])
    Rails.logger.debug hash.inspect
    hash.each do |h, s, p|
      line = ""
      line += "#{s}#{separator}" unless s.nil?
      line += "#{h}#{separator}#{p}"
      hash_lines << line
    end
    hash_lines.join("\n")
  end

  # Returns the count of hash items in the hash list.
  def hash_item_count
    hash_items.count
  end

  # Returns the number of hash items that have not been cracked yet.
  def uncracked_count
    hash_items.where(plain_text: nil).count
  end

  # Returns an ActiveRecord relation of uncracked hash items.
  #
  # @return [ActiveRecord::Relation] The uncracked hash items.
  def uncracked_items
    hash_items.where(cracked: false)
  end

  # Returns a string representation of the uncracked hash list.
  #
  # The uncracked hash list consists of hash values and their corresponding salts (if present),
  # separated by a separator character. The plain_text field of the hash items is checked to
  # determine if a hash is cracked or not. If the plain_text field is nil, the hash is considered
  # uncracked and included in the list.
  #
  # Example:
  #   hash_list = HashList.new
  #   hash_list.uncracked_list
  #   # => "salt1:hash1\nhash2\nsalt3:hash3"
  #
  # Returns:
  #   A string representation of the uncracked hash list.
  def uncracked_list
    hash_lines = []
    hash = hash_items.where(plain_text: nil).pluck(%i[hash_value salt])
    Rails.logger.debug hash.inspect
    hash.each do |h, s|
      line = ""
      line += "#{s}#{separator}" if s.present?
      line += "#{h}"
      hash_lines << line
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


  # Checks if a file is attached and not yet processed.
  #
  # Returns:
  # - true if a file is attached and not yet processed
  # - false otherwise
  def file_attached?
    file.attached? && !processed?
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
