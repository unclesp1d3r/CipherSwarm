# Residual Review Findings — Issue #568 (Broadcast Throttling)

**Branch:** `568-perf-implement-broadcast-throttlingdebouncing-for-high-throughput-scenarios` **Review run:** `/tmp/compound-engineering/ce-code-review/20260514-212512-1524616c/` **Reviewers:** ce-correctness, ce-testing, ce-maintainability, ce-project-standards, ce-agent-native, ce-learnings-researcher, ce-performance, ce-reliability, ce-kieran-rails; plus follow-up pr-review-toolkit comment-analyzer + silent-failure-hunter **Date:** 2026-05-14

## Resolution Status

All findings from both review passes are now addressed in-branch. This file is retained as a record of the review-to-resolution trace.

## Findings Resolved In-Branch

### From the ce-code-review autofix pass (`fix(review): apply autofix feedback`)

- Stale `BROADCAST_METHODS` comment (3-way reviewer agreement: project-standards, maintainability, kieran-rails) — comment updated.
- Misleading "co-temporal" comment on `Attack#broadcast_attack_progress_update` (3-way reviewer agreement) — replaced with accurate independent-throttle description.
- Missing REASONING block on `throttled_broadcast` (project-standards) — added per CONTRIBUTING.md.
- Rescue scope documented in YARD docstring (reliability) — narrow rescue scope explicitly noted.
- Fail-open spec missing at the model level (testing) — model-level fail-open contexts added to attack_spec and campaign_spec.
- Weak `locals:` assertion in attack broadcast spec (testing) — strengthened.

### From the full-resolution pass (`fix(review): resolve all residual findings`)

- **Throttle key namespace prefix (kieran-rails, P1).** Added `SafeBroadcasting::THROTTLE_KEY_PREFIX = "throttle:broadcast"`. All throttle keys are now stored as `throttle:broadcast:<concept>_<id>` so they cannot collide with application-level `Rails.cache` entries.
- **Production Redis `pool: false` (reliability, P1).** `config/environments/production.rb` now configures `pool: { size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i, timeout: 1 }`. Cache writes no longer serialize through a single Redis connection.
- **Pre-existing double-trigger (performance, P2).** `Attack#after_commit :safe_broadcast_attack_progress_update` is now guarded with `unless: -> { discarded? || saved_change_to_state? }`. State changes flow through the state-machine `after_transition` exclusively; non-state-change updates still flow through after_commit. Net: one cache write per event, not two.
- **Missing `safe_*` wrapper on AttackStateMachine (reliability, P2).** Added `Attack#safe_broadcast_attack_progress_update`, which rescues `StandardError` and logs via `StateChangeLogger.log_broadcast_error`. The state machine's `after_transition` now routes through this wrapper, so a render bug inside the throttled block cannot abort a state transition.
- **Block-raised exception leaves throttle key occupied (silent-failure-hunter, HIGH).** `throttled_broadcast` now wraps the yield in `begin/rescue/cache_delete/raise`, so a block exception releases the key before propagating. Eliminates the 5s post-failure suppression window.
- **Asymmetric rescue posture (silent-failure-hunter, MEDIUM).** `throttled_broadcast` now mirrors `BROADCAST_METHODS`: `EXPECTED_BROADCAST_ERRORS` (including the newly-added `Redis::BaseError`) fail open silently; other `StandardError`s fail open in production but re-raise in development.
- **Thin log context (silent-failure-hunter, MEDIUM).** `log_broadcast_error` now accepts an optional `context:` kwarg. The throttle path passes `"throttle:cache_write:<namespaced-key>"` so operators can distinguish cache-mutex failures from downstream broadcast failures in log scraping.
- **`Redis::BaseError` not in `EXPECTED_BROADCAST_ERRORS` (silent-failure-hunter, LOW).** Added — both the throttle path and the `BROADCAST_METHODS` wrapper now classify Redis connection errors as expected/fail-open.
- **Document Sidekiq enqueue failure → TTL-window blackout (reliability, P2).** Documented in `GOTCHAS.md`; the underlying issue is now fixed by the block-rescue path above. The remaining concern (operator visibility) is captured.
- **Document dev-vs-prod throttle behavior divergence (reliability, P3).** Documented in `GOTCHAS.md` with the `REDIS_URL` workaround.
- **`docs/solutions/best-practices/broadcast-throttling.md` (learnings-researcher, P3).** Written. Captures the leading-edge vs trailing-edge decision, fail-open posture, state-machine wrapper requirement, double-trigger guard, production Redis pool configuration, and dev environment caveat.

### From the pr-review-toolkit comment-analyzer pass

- **YARD `@yield` description was imprecise.** Replaced with `@yieldreturn` describing the block's passthrough return value.
- **`DEFAULT_THROTTLE_TTL` did not reference `HashItem::BROADCAST_DEBOUNCE_WINDOW`.** Comment updated to make the lockstep explicit so future changes prompt a check on the other.

## Coverage Notes

- All resolved findings are covered by new or updated specs in `spec/models/concerns/safe_broadcasting_spec.rb`, `spec/models/attack_spec.rb`, and `spec/models/campaign_spec.rb`. Coverage includes: namespaced key prefix, key release on block failure, rescue posture for both `EXPECTED_BROADCAST_ERRORS` and arbitrary `StandardError`, dev-environment re-raise, `context:` kwarg, `Attack#safe_broadcast_attack_progress_update` happy path and rescue path, and the after_commit double-trigger guard.
- `just ci-check` is the final gate. Re-run after every commit on this branch.
- The full ce-code-review synthesis artifact lives at `/tmp/compound-engineering/ce-code-review/20260514-212512-1524616c/synthesis.json`.
