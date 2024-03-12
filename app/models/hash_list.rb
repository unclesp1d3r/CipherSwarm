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
  has_one_attached :file
  belongs_to :project
  has_many :hash_items, dependent: :destroy

  validates_presence_of :name, :hash_mode
  validates_uniqueness_of :name
  validates_presence_of :file, on: :create
  validates_length_of :name, maximum: 255
  validates_length_of :separator, maximum: 1
  validates_numericality_of :metadata_fields_count, greater_than_or_equal_to: 0
  validates_presence_of :project

  after_save :process_hash_list, if: :file_attached?

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

  def uncracked_count
    self.hash_items.where(plain_text: nil).count
  end

  def cracked_count
    self.hash_items.where.not(plain_text: nil).count
  end

  def completion
    "#{self.cracked_count} / #{self.hash_items.count}"
  end

  def uncracked_list
    hash_lines = []
    hash = self.hash_items.where(plain_text: nil).pluck([ :hash_value, :salt ])
    puts hash.inspect
    hash.each do |h, s|
      line = ""
      if s.nil?
        line += "#{s}#{self.separator}"
      end
      line += "#{h}"
      hash_lines << line
    end
    hash_lines.join("\n")
  end

  def cracked_list
    hash_lines = []
    hash = self.hash_items.where.not(plain_text: nil).pluck([ :hash_value, :salt, :plain_text ])
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

  private

  def file_attached?
    file.attached? && !self.processed?
  end

  def process_hash_list
    ProcessHashListJob.perform_later(self.id)
  end
end
