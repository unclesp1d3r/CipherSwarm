# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Represents a type of hash with its attributes and behaviors.
#
# @relationships
# - has_many :hash_lists (restrict_with_error)
#
# @validations
# - name: present, unique, max 255 chars
# - hashcat_mode: present, unique, integer
# - category: present
#
# @scopes
# - enabled/disabled: by enabled status
# - slow/fast: by speed flag
# - built_in/custom: by origin
# - default: ordered by hashcat_mode
#
# @enums
# - category: defines hash type categories (raw_hash, salted_hash, etc.)
#
# @aliases
# - hash_mode: aliased to hashcat_mode
#
# == Schema Information
#
# Table name: hash_types
#
#  id                                          :bigint           not null, primary key
#  built_in(Whether the hash type is built-in) :boolean          default(FALSE), not null
#  category(The category of the hash type)     :integer          default("raw_hash"), not null
#  enabled(Whether the hash type is enabled)   :boolean          default(TRUE), not null
#  hashcat_mode(The hashcat mode number)       :integer          not null, uniquely indexed
#  is_slow(Whether the hash type is slow)      :boolean          default(FALSE), not null
#  name(The name of the hash type)             :string           not null, uniquely indexed
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
    "#{hashcat_mode} (#{name})"
  end
end
