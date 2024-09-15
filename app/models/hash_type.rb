# frozen_string_literal: true

# The HashType model represents different types of hash algorithms and their associated metadata.
# It includes various validations, scopes, and an enumeration for categorizing hash types.
#
# This is generally derived from the hashcat modes and is used to track the different types of hashes that can be cracked.
#
# Associations:
# - has_many :hash_lists, dependent: :restrict_with_error
#
# Validations:
# - name: presence, uniqueness, length (maximum 255)
# - hashcat_mode: presence, uniqueness, numericality (only integer)
# - category: presence
#
# Scopes:
# - default_scope: orders by :hashcat_mode
# - enabled: filters where enabled is true
# - disabled: filters where enabled is false
# - slow: filters where is_slow is true
# - fast: filters where is_slow is false
# - built_in: filters where built_in is true
# - custom: filters where built_in is false
#
# Enums:
# - category: defines various categories of hash types with integer values
#
# Instance Methods:
# - to_s: returns a string representation of the hash type in the format "hashcat_mode (name)"
#
# == Schema Information
#
# Table name: hash_types
#
#  id                                          :bigint           not null, primary key
#  built_in(Whether the hash type is built-in) :boolean          default(FALSE), not null
#  category(The category of the hash type)     :integer          default("raw_hash"), not null
#  enabled(Whether the hash type is enabled)   :boolean          default(TRUE), not null
#  hashcat_mode(The hashcat mode number)       :integer          not null, indexed
#  is_slow(Whether the hash type is slow)      :boolean          default(FALSE), not null
#  name(The name of the hash type)             :string           not null, indexed
#  created_at                                  :datetime         not null
#  updated_at                                  :datetime         not null
#
# Indexes
#
#  index_hash_types_on_hashcat_mode  (hashcat_mode) UNIQUE
#  index_hash_types_on_name          (name) UNIQUE
#

class HashType < ApplicationRecord
  has_many :hash_lists, dependent: :restrict_with_error
  validates :name, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :hashcat_mode, presence: true, uniqueness: true, numericality: { only_integer: true }
  validates :category, presence: true

  default_scope { order(:hashcat_mode) }
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :slow, -> { where(is_slow: true) }
  scope :fast, -> { where(is_slow: false) }
  scope :built_in, -> { where(built_in: true) }
  scope :custom, -> { where(built_in: false) }

  enum :category, {
    raw_hash: 0,
    salted_hash: 1,
    raw_hash_authenticated: 2,
    raw_checksum: 3,
    raw_cipher: 4,
    generic_kdf: 5,
    network_protocol: 6,
    operating_system: 7,
    database_server: 8,
    ftp_http_smtp_ldap_server: 9,
    enterprise_application_software: 10,
    fulldisk_encryption_software: 11,
    document: 12,
    password_manager: 13,
    archive: 14,
    forums_cms_ecommerce: 15,
    otp: 16,
    plaintext: 17,
    framework: 18,
    private_key: 19,
    instant_messaging: 20,
    cryptocurrency: 21
  }

  def to_s
    "#{hash_type.hashcat_mode} (#{hash_type.name})"
  end
end
