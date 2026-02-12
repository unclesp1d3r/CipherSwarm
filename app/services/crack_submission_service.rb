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
# REASONING:
# - Extracted ~50 lines of complex logic from TasksController#submit_crack for better testability.
# - Multiple database operations and cross-model updates warrant a dedicated service object.
# Alternatives Considered:
# - Keep in controller: Makes controller fat (~100+ lines) and hard to test in isolation.
# - Model callback: Would create hidden side effects and tight coupling between models.
# - Interactor gem: Adds dependency for simple use case; Struct-based Result is sufficient.
# Decision:
# - Plain Ruby service class with Result Struct provides testability and clear interface.
# - Uses database transaction to ensure atomicity of crack propagation.
# Performance Implications:
# - Batch update for propagating cracks to matching hashes (single query vs N+1).
# - Transaction overhead is acceptable given data consistency requirements.
# Future Considerations:
# - Could add async crack propagation for very large hash lists.
# - Consider caching uncracked_count if called frequently.
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
    # rubocop:disable Rails/SkipsModelValidations
    HashItem.joins(:hash_list)
            .where(hash_value: hash_item.hash_value, cracked: false)
            .where(hash_lists: { hash_type_id: hash_list.hash_type_id })
            .update_all(
              plain_text: plain_text,
              cracked: true,
              cracked_time: timestamp,
              attack_id: task.attack_id
            )
    # rubocop:enable Rails/SkipsModelValidations
  end

  # Marks tasks for other campaigns targeting this hash list as stale.
  #
  # @param hash_list [HashList] the hash list
  def mark_related_tasks_stale(hash_list)
    # rubocop:disable Rails/SkipsModelValidations
    Task.joins(attack: :campaign)
        .where(campaigns: { hash_list_id: hash_list.id })
        .where.not(id: task.id)
        .update_all(stale: true)
    # rubocop:enable Rails/SkipsModelValidations
  end

  # Touches the campaign to trigger cache invalidation.
  def touch_campaign
    task.attack.campaign.touch # rubocop:disable Rails/SkipsModelValidations
  end
end
