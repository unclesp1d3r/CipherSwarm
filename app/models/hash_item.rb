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
  #
  # Each campaign enqueue is wrapped in its own rescue so a transient
  # failure for one sibling (e.g. Redis hiccup, Sidekiq enqueue error)
  # does not suppress broadcasts for the others sharing this hash list.
  #
  # The campaign-id list itself is cached per hash_list for the same
  # debounce window so high-rate crack streams don't run the
  # `campaigns WHERE hash_list_id = ?` query on every commit.
  #
  # @return [void]
  def broadcast_recent_cracks_update
    campaign_ids_for_broadcast.each do |campaign_id|
      enqueue_recent_cracks_broadcast(campaign_id)
    end
  rescue StandardError => e
    Rails.logger.error("[BroadcastUpdate] HashItem #{id} - Failed to load campaigns for recent cracks broadcast: #{e.message}")
  end

  # Returns the campaign ids that should receive recent-cracks broadcasts,
  # memoized at the cache layer for the debounce window. Stale by at most
  # BROADCAST_DEBOUNCE_WINDOW when a campaign is newly attached to this
  # hash list — acceptable for a UI refresh signal.
  #
  # @return [Array<Integer>] campaign ids in ascending order
  def campaign_ids_for_broadcast
    Rails.cache.fetch("hash_list:#{hash_list_id}:broadcast_campaign_ids", expires_in: BROADCAST_DEBOUNCE_WINDOW) do
      hash_list.campaigns.order(:id).pluck(:id)
    end
  end

  # Enqueues a single BroadcastRecentCracksJob if the per-campaign debounce
  # key is not already held. Failures (cache, Sidekiq, etc.) are logged but
  # do not propagate, so they cannot abort sibling enqueues.
  #
  # @param campaign_id [Integer] the campaign whose recent_cracks panel should refresh
  # @return [void]
  def enqueue_recent_cracks_broadcast(campaign_id)
    debounce_key = "broadcast_recent_cracks:#{hash_list_id}:#{campaign_id}"
    return unless Rails.cache.write(debounce_key, true, expires_in: BROADCAST_DEBOUNCE_WINDOW, unless_exist: true)

    BroadcastRecentCracksJob.perform_later(campaign_id)
  rescue StandardError => e
    Rails.logger.error("[BroadcastUpdate] HashItem #{id} - Failed to enqueue recent cracks broadcast for campaign #{campaign_id}: #{e.message}")
  end
end
