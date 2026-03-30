# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# REASONING:
# - Why: VerifyChecksumJob can fail silently (I/O errors, file not found, transient
#   storage issues) leaving resources permanently stuck with checksum_verified=false
#   and no alert. This periodic job detects stale unverified resources and re-enqueues
#   VerifyChecksumJob so they get another verification attempt.
# - Alternatives: rely on operators to notice unverified resources in the dashboard
#   (unacceptable — air-gapped deployments have no external monitoring), add retry
#   logic inside VerifyChecksumJob itself (already had retries, but previously
#   discarded after exhaustion with no re-enqueue mechanism — this job fills that gap).
# - Decision: periodic sweep job following DataCleanupJob's proven structure with
#   per-resource-type error isolation and summary logging.
# - Threshold: configurable via ApplicationConfig.checksum_verification_retry_threshold
#   (default 6 hours) so operators can tune for their storage reliability profile.

class RequeueUnverifiedResourcesJob < ApplicationJob
  queue_as :low

  # Performs the requeue sweep for all three resource types.
  # Tracks failures and reports a summary at the end.
  #
  # @return [void]
  def perform
    @failures = []

    ActiveRecord::Base.connection_pool.with_connection do
      requeue_word_lists
      requeue_rule_lists
      requeue_mask_lists
    end
  ensure
    report_summary
    ActiveRecord::Base.connection_handler.clear_active_connections!
  end

  private

  # Reports a summary of the requeue sweep.
  # Logs errors if any resource type failed, or confirms the sweep ran.
  #
  # @return [void]
  def report_summary
    if @failures.any?
      Rails.logger.error(
        "[RequeueUnverified] Requeue completed with #{@failures.size} failure(s): #{@failures.join(', ')}"
      )
    else
      Rails.logger.info("[RequeueUnverified] Sweep complete — all resource types processed successfully")
    end
  end

  def requeue_word_lists = requeue_resources(WordList, :word_lists)
  def requeue_rule_lists = requeue_resources(RuleList, :rule_lists)
  def requeue_mask_lists = requeue_resources(MaskList, :mask_lists)

  # Enqueues VerifyChecksumJob for each stale unverified resource of the given type.
  # Touches updated_at on each resource to reset the staleness clock, preventing
  # duplicate enqueues on subsequent sweep runs.
  #
  # @param model_class [Class] the ActiveRecord model to query
  # @param failure_key [Symbol] identifier for failure tracking
  # @return [void]
  def requeue_resources(model_class, failure_key)
    cutoff = ApplicationConfig.checksum_verification_retry_threshold.ago
    stale_resources = model_class.checksum_unverified.where(updated_at: ...cutoff)

    count = 0
    stale_resources.find_each do |resource|
      begin
        VerifyChecksumJob.perform_later(resource.id, resource.class.name)
        resource.update_column(:updated_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
        count += 1
      rescue StandardError => e
        @failures << failure_key unless @failures.include?(failure_key)
        log_requeue_error("#{model_class.name}##{resource.id}", e)
      end
    end

    if count.positive?
      Rails.logger.info(
        "[RequeueUnverified] Enqueued #{count} #{model_class.name} resource(s) for checksum verification"
      )
    end
  rescue StandardError => e
    @failures << failure_key
    log_requeue_error(model_class.name, e)
  end

  # Logs a requeue error with backtrace.
  #
  # @param resource_name [String] Name of the resource type being requeued
  # @param error [StandardError] The error that occurred
  # @return [void]
  def log_requeue_error(resource_name, error)
    backtrace = error.backtrace&.first(5)&.join("\n           ") || "Not available"
    Rails.logger.error(
      "[RequeueUnverified] Error requeuing #{resource_name}: #{error.class} - #{error.message}\n" \
      "           Backtrace: #{backtrace}"
    )
  end
end
