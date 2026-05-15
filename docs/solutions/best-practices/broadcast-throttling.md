---
title: Throttling high-frequency Turbo Stream broadcasts
date: 2026-05-14
category: best-practices
module: broadcasting
problem_type: best_practice
component: rails_model
severity: high
applies_when:
  - Adding a Turbo Stream broadcast to a model that fires on Task transitions, HashItem updates, or agent heartbeats
  - Diagnosing Puma latency spikes correlated with high-concurrency agent activity
  - Reviewing a PR that introduces `broadcast_replace_to` on a hot callback path
  - Choosing between leading-edge and trailing-edge debouncing for a new broadcast
tags: [broadcasting, turbo-streams, throttling, debouncing, sidekiq, safe-broadcasting, performance]
---

# Throttling high-frequency Turbo Stream broadcasts

## Problem

Models that broadcast Turbo Stream updates via `after_commit` / state-machine `after_transition` callbacks can saturate Puma workers under sustained agent load. The canonical hot path before issue #568:

```text
Task#accept_crack!
  → AttackStateMachine after_transition
      → Attack#broadcast_attack_progress_update
          → broadcast_replace_to (sync render on the request thread)
              → Campaign#broadcast_eta_update
                  → broadcast_replace_to (sync render on the request thread)
```

With 10+ concurrent agents each submitting cracks, every `Task` transition rendered two Turbo frames synchronously. Puma worker time was spent on frames the client never observed.

## Solution

Use `SafeBroadcasting#throttled_broadcast(key, ttl:)` to gate the broadcast with an atomic `SET NX EX` (`Rails.cache.write(..., unless_exist: true)`), and switch the inner call to `broadcast_replace_later_to` so the render runs in Sidekiq.

```ruby
def broadcast_attack_progress_update
  throttled_broadcast("attack_progress_#{id}") do
    broadcast_replace_later_to(
      campaign,
      target: "attack-progress-#{id}",
      partial: "campaigns/attack_progress",
      locals: { ... }
    )
    campaign.broadcast_eta_update
  end
end
```

The helper namespaces the supplied key as `throttle:broadcast:<your-key>` so it cannot collide with application-level `Rails.cache` entries.

## Leading-edge vs trailing-edge

| Pattern                                      | When to use                                                                                                                                                                                                                      | Example                                                                                                     |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Leading-edge** (`throttled_broadcast`)     | Continuous-value displays where the UI must stay live during a burst. The first event in the window fires immediately; the rest are suppressed for the TTL. Up to one window of staleness at the tail.                           | `Attack#broadcast_attack_progress_update`, `Campaign#broadcast_eta_update`                                  |
| **Trailing-edge** (cache gate + delayed job) | Snapshot panels where only the final state matters. The first event sets a gate and enqueues a job with `wait: ttl`; later events in the window enqueue nothing; the job runs once at the end and renders the accumulated state. | `HashItem#broadcast_recent_cracks_update` via `BroadcastRecentCracksJob.set(wait: 5.seconds).perform_later` |

Pick by user experience, not write frequency:

- "What does the user need to see right now?" → leading-edge
- "What does the user need to see when this finishes?" → trailing-edge

## Fail-open posture

`throttled_broadcast` has two distinct fail-open paths:

1. **Cache-write fails (Redis outage, timeout).** The helper logs the error with a `Context: throttle:cache_write:<key>` tag and yields the block. An unthrottled frame is preferable to silently suppressing every UI update.

2. **Block raises after the key was set.** The helper deletes the throttle key before re-raising. Without this, a single bug in the yielded code would cause a 5-second blackout per record where the throttle appears active but no broadcast ever fired.

Rescue posture mirrors the sibling `BROADCAST_METHODS` override: connection-class errors (`EXPECTED_BROADCAST_ERRORS` — `IOError`, `Errno::ECONNREFUSED/RESET/EPIPE`, `Redis::BaseError`) fail open silently in any environment; other `StandardError`s fail open in production but re-raise in development so bugs surface during a normal `bin/dev` run.

## State-machine callers need `safe_*` wrappers

The `state_machines` gem treats an unrescued exception inside an `after_transition` callback as a rollback signal. If a render bug inside the throttled block propagates up through the state machine, it silently reverts the transition. Use a `safe_*` wrapper that rescues `StandardError` and routes it through `StateChangeLogger.log_broadcast_error`:

```ruby
# In app/models/attack.rb
def safe_broadcast_attack_progress_update
  broadcast_attack_progress_update
rescue StandardError => e
  StateChangeLogger.log_broadcast_error(
    model_name: "Attack",
    record_id: id,
    error: e,
    context: { target: "attack-progress-#{id}", partial: "campaigns/attack_progress" }
  )
end

# In app/models/concerns/attack_state_machine.rb
after_transition any => %i[running completed exhausted failed paused],
                 do: :safe_broadcast_attack_progress_update
```

## Avoiding double-triggers

A model that fires the same broadcast from both an `after_transition` and an `after_commit on: [:update]` will hit both callbacks on every state change. The throttle absorbs the redundant call, but the redundant `SET NX EX` round-trip costs measurable Redis bandwidth under high concurrent agent load. Guard the `after_commit` with `unless: -> { saved_change_to_state? }` so the after_transition is the sole trigger for state moves while after_commit still covers non-state-change updates (counter cache touches, attribute edits):

```ruby
after_commit :safe_broadcast_attack_progress_update,
             on: [:update],
             unless: -> { discarded? || saved_change_to_state? }
```

## Production Redis pool

`throttled_broadcast` adds per-callback `Rails.cache.write` calls on the request path. Production must configure a connection pool — `pool: false` (a single shared Redis connection) becomes a serialization point under 10+ concurrent agent load:

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"),
  pool: {
    size: ENV.fetch("RAILS_MAX_THREADS", 5).to_i,
    timeout: 1
  }
}
```

Pool size matches the Puma thread budget; `timeout: 1` fails fast rather than stacking requests behind cache I/O.

## Dev environment caveat

When `REDIS_URL` is unset in development, `config/environments/development.rb` defaults to `:null_store`. NullStore's `write` always returns `true` regardless of `unless_exist:`, so throttling never suppresses anything in dev. Broadcasts are still async (Sidekiq is configured), but the suppression semantic only kicks in against a real Redis. Set `REDIS_URL=redis://localhost:6379/0` locally to mirror production behavior.

## Cross-references

- [Choosing between ID+TTL and version-based cache keys in Rails](cache-key-strategy.md) — validates the `Rails.cache.write(..., unless_exist: true)` pattern this helper uses.
- `app/models/concerns/safe_broadcasting.rb` — the helper itself, with the full REASONING block per CONTRIBUTING.md.
- `app/models/hash_item.rb` — trailing-edge debounce example via `BroadcastRecentCracksJob`.
