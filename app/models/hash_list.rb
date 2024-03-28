# == Schema Information
#
# Table name: hash_lists
#
#  id                                                                                                                        :bigint           not null, primary key
#  description(Description of the hash list)                                                                                 :text
#  hash_mode(Hash mode of the hash list (hashcat mode))                                                                      :integer          not null, indexed
#  metadata_fields_count(Number of metadata fields in the hash list file. Default is 0.)                                     :integer          default(0), not null
#  name(Name of the hash list)                                                                                               :string           not null, indexed
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
  audited
  has_one_attached :file
  belongs_to :project, touch: true
  has_one :campaign, dependent: :destroy
  has_many :hash_items, dependent: :destroy
  has_and_belongs_to_many :attacks, dependent: :destroy

  validates_presence_of :name, :hash_mode
  validates_uniqueness_of :name, scope: :project_id, case_sensitive: false
  validates_presence_of :file, on: :create
  validates_length_of :name, maximum: 255
  validates_length_of :separator, is: 1, allow_blank: true
  validates_numericality_of :metadata_fields_count, greater_than_or_equal_to: 0, only_integer: true
  validates_presence_of :project
  validates :file, content_type: %w[text/plain], attached: ->(record) { record.processed? || record.file.attached? }

  broadcasts_refreshes unless Rails.env.test?

  scope :sensitive, -> { where(sensitive: true) }

  after_save :process_hash_list, if: :file_attached?
  after_update :update_status
  enum hash_mode: {
    md5: 0,
    sha1: 100,
    sha256: 1400,
    sha512: 1700,
    ntlm: 1000,
    ntlm_challenge: 5600,
    ntlm_challenge_unicode: 5700,
    ntlm_v2: 5600,
    ntlm_v2_unicode: 5700,
    lm: 3000,
    lm_challenge: 5500,
    lm_challenge_unicode: 5500,
    lm_v2: 5600,
    sha512crypt: 1800,
    md5crypt: 500,
    bcrypt: 3200,
    sha256crypt: 7400,
    sha512crypt_bsd: 1800,
    sha256crypt_bsd: 7400
  }

  # Returns the count of hash items that have not been cracked yet.
  def uncracked_count
    self.hash_items.where(plain_text: nil).count
  end

  # Returns the count of hash items that have been cracked (i.e., have a non-nil plain_text value).
  def cracked_count
    self.hash_items.where.not(plain_text: nil).count
  end

  # Returns a string representing the completion status of the hash list.
  #
  # The completion status is calculated by dividing the number of cracked items
  # by the total number of hash items in the list.
  #
  # @return [String] The completion status in the format "cracked_count / total_count".
  def completion
    "#{self.cracked_count} / #{self.hash_items.count}"
  end

  # Returns a string representation of the uncracked hash list.
  #
  # This method retrieves the hash items from the database where the plain_text is nil,
  # and constructs a string representation of the uncracked hash list.
  #
  # @return [String] The uncracked hash list as a string.
  def uncracked_list
    hash_lines = []
    hash = self.hash_items.where(plain_text: nil).pluck([:hash_value, :salt])
    puts hash.inspect
    hash.each do |h, s|
      line = ""
      if s.present?
        line += "#{s}#{self.separator}"
      end
      line += "#{h}"
      hash_lines << line
    end
    hash_lines.join("\n")
  end

  # Returns the checksum of the uncracked hash list.
  def uncracked_list_checksum
    md5 = OpenSSL::Digest::MD5.new
    md5.update(uncracked_list)
    md5.base64digest
  end

  # Returns a formatted string representation of the cracked hash items in the hash list.
  #
  # The method retrieves the hash items from the database where the plain_text is not nil,
  # and constructs a string representation for each cracked hash item. The string representation
  # includes the hash value, salt (if present), and plain text. The cracked hash items are
  # then joined together with a separator and returned as a single string.
  #
  # @return [String] The formatted string representation of the cracked hash items.
  def cracked_list
    hash_lines = []
    hash = self.hash_items.where.not(plain_text: nil).pluck([:hash_value, :salt, :plain_text])
    puts hash.inspect
    hash.each do |h, s, p|
      line = ""
      if s.nil?
        line += "#{s}#{self.separator}"
      end
      line += "#{h}#{self.separator}#{p}"
      hash_lines << line
    end
    hash_lines.join("\n")
  end

  def uncracked_items
    self.hash_items.where(cracked: false)
  end

  def update_status
    if self.uncracked_count == 0
      transaction do
        self.campaign.attacks.where.not(status: :completed).each do |attack|
          attack.update(status: :completed)
          attack.tasks.update(status: :completed)
        end
      end
    end
  end

  private

  # Checks if a file is attached and if the hash list has been processed.
  #
  # Returns:
  # - true if a file is attached and the hash list has not been processed.
  # - false otherwise.
  def file_attached?
    file.attached? && !self.processed?
  end

  # Processes the hash list by scheduling a background job to perform the processing.
  #
  # This method is responsible for initiating the processing of the hash list by
  # scheduling a background job using the `ProcessHashListJob` class. The job is
  # scheduled to run asynchronously, allowing the processing to be performed in the
  # background without blocking the main thread.
  #
  # @return [void]
  def process_hash_list
    if Rails.env.test?
      ProcessHashListJob.perform_now(self.id)
      return
    end
    ProcessHashListJob.perform_later(self.id)
  end
end
