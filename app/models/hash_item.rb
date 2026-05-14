# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Represents an individual hash entry with its cracking status and metadata.
#
# @relationships
# - belongs_to :hash_list (touch: true, counter_cache: true)
# - belongs_to :attack (optional)
#
# @validations
# - hash_value: present
# - salt, plain_text: max 255 chars
# - metadata: max 255 chars
#
# @scopes
# - cracked: items with cracked status
# - uncracked: items without cracked status
#
# @methods
# - to_s: formats as "hash_value:salt:plain_text" or "hash_value:plain_text"
#
# == Schema Information
#
# Table name: hash_items
#
#  id                                                                   :bigint           not null, primary key
#  cracked(Is the hash cracked?)                                        :boolean          default(FALSE), not null, indexed => [hash_value_digest]
#  cracked_time(Time when the hash was cracked)                         :datetime         indexed
#  hash_value(Hash value)                                               :text             not null
#  hash_value_digest(MD5 fingerprint of hash_value for B-tree indexing) :string(32)       not null, indexed => [cracked], indexed => [hash_list_id]
#  metadata(Optional metadata fields for the hash item.)                :jsonb            not null
#  plain_text(Plaintext value of the hash)                              :string
#  salt(Salt of the hash)                                               :text
#  created_at                                                           :datetime         not null
#  updated_at                                                           :datetime         not null
#  attack_id(The attack that cracked this hash)                         :bigint           indexed, indexed => [hash_list_id]
#  hash_list_id                                                         :bigint           not null, indexed, indexed => [attack_id], indexed => [hash_value_digest]
#
# Indexes
#
#  index_hash_items_on_attack_id                           (attack_id)
#  index_hash_items_on_cracked_time                        (cracked_time)
#  index_hash_items_on_hash_list_id                        (hash_list_id)
#  index_hash_items_on_hash_list_id_and_attack_id          (hash_list_id,attack_id)
#  index_hash_items_on_hash_value_digest_and_cracked       (hash_value_digest,cracked)
#  index_hash_items_on_hash_value_digest_and_hash_list_id  (hash_value_digest,hash_list_id)
#
# Foreign Keys
#
#  fk_rails_...  (attack_id => attacks.id) ON DELETE => nullify
#  fk_rails_...  (hash_list_id => hash_lists.id) ON DELETE => cascade
#
class HashItem < ApplicationRecord
  belongs_to :hash_list, touch: true, counter_cache: true
  belongs_to :attack, optional: true
  before_validation :set_hash_value_digest
  validates :hash_value, presence: true
  validates :hash_value_digest, presence: true
  validates :salt, length: { maximum: 255 }
  validates :plain_text, length: { maximum: 255 }
  validates :metadata, length: { maximum: 255 }

  scope :cracked, -> { where(cracked: true) }
  scope :uncracked, -> { where(cracked: false) }

  include SafeBroadcasting

  # Debounce window for "recent cracks" broadcasts. With ~25 RTX 4090s producing
  # thousands of cracks per second, an unthrottled broadcast per crack per
  # campaign overwhelms Action Cable. Capping at one broadcast per
  # (hash_list_id, campaign_id) per BROADCAST_DEBOUNCE_WINDOW keeps the UI
  # eventually-consistent without DOM thrash.
  BROADCAST_DEBOUNCE_WINDOW = 5.seconds

  after_commit :broadcast_recent_cracks_update, on: [:update], if: :just_cracked?

  # Returns a string representation of the hash item.
  # If the salt is present, the format will be "hash_value:salt:plain_text".
  # Otherwise, the format will be "hash_value:plain_text".
  #
  # @return [String] the string representation of the hash item.
  def to_s
    if salt.present?
      "#{hash_value}:#{salt}:#{plain_text}"
    else
      "#{hash_value}:#{plain_text}"
    end
  end

  private

  def set_hash_value_digest
    self.hash_value_digest = Digest::MD5.hexdigest(hash_value) if hash_value.present?
  end

  # Returns true if cracked transitioned from false to true in this commit.
  #
  # @return [Boolean] true if just cracked, false otherwise.
  def just_cracked?
    saved_change_to_cracked? && cracked?
  end

  # Enqueues at most one BroadcastRecentCracksJob per campaign per debounce
  # window. Uses Rails.cache.write(..., unless_exist: true) — an atomic
  # Redis SET NX EX — so only the first crack in each window wins.
  def broadcast_recent_cracks_update
    hash_list.campaigns.find_each do |campaign|
      debounce_key = "broadcast_recent_cracks:#{hash_list_id}:#{campaign.id}"
      next unless Rails.cache.write(debounce_key, true, expires_in: BROADCAST_DEBOUNCE_WINDOW, unless_exist: true)

      BroadcastRecentCracksJob.perform_later(campaign.id)
    end
  rescue StandardError => e
    Rails.logger.error("[BroadcastUpdate] HashItem #{id} - Failed to enqueue recent cracks broadcast: #{e.message}")
  end
end
