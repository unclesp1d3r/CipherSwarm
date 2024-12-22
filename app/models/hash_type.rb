# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# This class represents a type of hash, including its associated attributes
# and behaviors. It is powered by ActiveRecord and provides validations,
# scopes, and enumerations for easy management of hash-related data.
#
# Associations:
# * `has_many :hash_lists` - Establishes a one-to-many relationship
#   with the `HashList` model. Ensures associated `hash_lists` cannot
#   be destroyed if there are dependent records.
#
# Validations:
# * `name` - Must be present, unique, and not exceed 255 characters.
# * `hashcat_mode` - Must be present, unique, and a valid integer.
# * `category` - Must be present.
#
# Scopes:
# * `enabled` - Retrieves only enabled hash types.
# * `disabled` - Retrieves only disabled hash types.
# * `slow` - Retrieves hash types marked as slow.
# * `fast` - Retrieves hash types marked as fast.
# * `built_in` - Retrieves built-in hash types.
# * `custom` - Retrieves user-custom hash types (non-built-in).
#
# Default Scope:
# * Ordering is set to sort hash types by the `hashcat_mode` attribute.
#
# Enumerations:
# * `category` - Defines multiple categories of hash types,
#   such as `raw_hash`, `salted_hash`, `database_server`, etc.
#   The enumeration values are stored as integers in the database.
#
# Aliases:
# * `hashcat_mode` is aliased as `hash_mode` for accessibility.
#
# Instance Methods:
# * `to_s` - Provides a string representation of the hash type,
#   combining its `hashcat_mode` and `name`.
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

  alias_attribute :hash_mode, :hashcat_mode

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
