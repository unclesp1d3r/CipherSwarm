# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# CrackSubmissionService handles the business logic for processing cracked hash submissions.
#
# This service encapsulates the complex logic previously in TasksController#submit_crack,
# including:
# - Finding and updating the cracked hash item
# - Updating the task state
# - Propagating the crack to other hash items with the same value
# - Marking related tasks as stale
#
# @example Basic usage
#   result = CrackSubmissionService.new(
#     task: task,
#     hash_value: "abc123...",
#     plain_text: "password123",
#     timestamp: Time.current
#   ).call
#
#   if result.success?
#     # Crack processed successfully
#   else
#     # Handle error: result.error, result.error_type
#   end
#
class CrackSubmissionService
  # Result object for service outcomes
  Result = Struct.new(:success?, :error, :error_type, :uncracked_count, keyword_init: true)

  # @return [Task] the task submitting the crack
  attr_reader :task

  # @return [String] the hash value that was cracked
  attr_reader :hash_value

  # @return [String] the plain text (password) for the crack
  attr_reader :plain_text

  # @return [Time] when the crack occurred
  attr_reader :timestamp

  # Initializes a new CrackSubmissionService.
  #
  # @param task [Task] the task submitting the crack
  # @param hash_value [String] the hash value that was cracked
  # @param plain_text [String] the plain text (password) for the crack
  # @param timestamp [Time] when the crack occurred
  def initialize(task:, hash_value:, plain_text:, timestamp:)
    @task = task
    @hash_value = hash_value
    @plain_text = plain_text
    @timestamp = timestamp
  end

  # Processes the crack submission.
  #
  # @return [Result] the result of the operation
  def call
    hash_list = task.hash_list
    hash_item = find_hash_item(hash_list)
    return hash_item if hash_item.is_a?(Result) # Error result

    process_crack(hash_list, hash_item)
  end

  private

  # Finds the hash item in the hash list.
  #
  # @param hash_list [HashList] the hash list to search
  # @return [HashItem, Result] the hash item or an error result
  def find_hash_item(hash_list)
    hash_item = hash_list.hash_items.find_by(hash_value: hash_value)
    return Result.new(success?: false, error: "Hash not found", error_type: :not_found) if hash_item.blank?

    hash_item
  end

  # Processes the crack within a transaction.
  #
  # @param hash_list [HashList] the hash list containing the hash
  # @param hash_item [HashItem] the hash item to update
  # @return [Result] the result of the operation
  def process_crack(hash_list, hash_item)
    HashItem.transaction do
      update_hash_item!(hash_item)
      accept_crack!
      propagate_crack_to_matching_hashes(hash_list, hash_item)
      mark_related_tasks_stale(hash_list)
      touch_campaign

      Result.new(
        success?: true,
        uncracked_count: hash_list.uncracked_count,
        error: nil,
        error_type: nil
      )
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.new(success?: false, error: e.record.errors.full_messages.join(", "), error_type: :validation_error)
  end

  # Updates the hash item with crack information.
  #
  # @param hash_item [HashItem] the hash item to update
  # @raise [ActiveRecord::RecordInvalid] if validation fails
  def update_hash_item!(hash_item)
    hash_item.update!(
      plain_text: plain_text,
      cracked: true,
      cracked_time: timestamp,
      attack: task.attack
    )
  end

  # Marks the task as having accepted a crack.
  #
  # @raise [ActiveRecord::RecordInvalid] if the state transition fails
  def accept_crack!
    return if task.accept_crack

    raise ActiveRecord::RecordInvalid.new(task)
  end

  # Propagates the crack to other hash items with the same value and hash type.
  #
  # @param hash_list [HashList] the source hash list
  # @param hash_item [HashItem] the cracked hash item
  def propagate_crack_to_matching_hashes(hash_list, hash_item)
    HashItem.includes(:hash_list)
            .where(hash_value: hash_item.hash_value, cracked: false, hash_list: { hash_type_id: hash_list.hash_type_id })
            .update!(plain_text: plain_text, cracked: true, cracked_time: timestamp, attack: task.attack)
  end

  # Marks tasks for other campaigns targeting this hash list as stale.
  #
  # @param hash_list [HashList] the hash list
  def mark_related_tasks_stale(hash_list)
    hash_list.campaigns.each do |campaign|
      campaign.attacks.each do |attack|
        attack.tasks.where.not(id: task.id).update(stale: true)
      end
    end
  end

  # Touches the campaign to trigger cache invalidation.
  def touch_campaign
    task.attack.campaign.touch # rubocop:disable Rails/SkipsModelValidations
  end
end
