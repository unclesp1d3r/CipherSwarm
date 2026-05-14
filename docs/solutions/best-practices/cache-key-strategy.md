---
title: Choosing between ID+TTL and version-based cache keys in Rails
date: 2026-05-13
category: best-practices
module: caching
problem_type: best_practice
component: rails_model
severity: medium
applies_when:
  - Adding `Rails.cache.fetch` to a model method or service
  - Diagnosing cache-miss storms caused by `touch: true` cascades
  - Deciding whether a `belongs_to ..., touch: true` is needed for cache invalidation
  - Reviewing PRs that introduce `cache_key_with_version` in hot paths
tags: [caching, touch-cascade, cache-key-with-version, broadcasts-refreshes, performance]
---

# Choosing between ID+TTL and version-based cache keys in Rails

## Context

Rails offers two cache-key strategies that look interchangeable but invalidate very differently:

- **Version-based**: `"#{record.cache_key_with_version}/suffix"` — invalidated on every `updated_at` change.
- **ID+TTL**: `"model/#{record.id}/suffix"` with `expires_in:` — invalidated only on a wall clock.

A version-based key on a hot record turns every cascading `touch: true` into a cache miss. Because `touch: true` propagates `updated_at` up the association chain, a single high-frequency write at the leaf can bust caches on the root. In CipherSwarm, this manifested as `HashcatStatus → Task → Attack` touches busting the `CampaignEtaCalculator` cache on every status poll (every 5–30 seconds per agent), defeating the cache entirely.

Resolved in PRs that addressed cache-miss storms on `CampaignEtaCalculator` and `HashList` counters. See `app/services/campaign_eta_calculator.rb` and `app/models/hash_list.rb` for the resulting pattern.

## Guidance

### Use ID+TTL for high-write data

When the underlying data changes faster than the acceptable staleness window, version-based keys are worse than no cache at all (one DB query for the version probe, then another for the miss). Switch to ID+TTL:

```ruby
def current_eta
  Rails.cache.fetch("campaign/#{campaign.id}/eta/current_eta", expires_in: 1.minute) do
    calculate_current_eta
  end
end
```

Pick TTL by tolerable staleness, not by record volatility. ETA and progress estimates tolerate 30–60s; per-request counters often tolerate 30s; rarely-changing aggregate counts tolerate 20m.

### Use version-based for low-write, configuration-level data

`cache_key_with_version` is correct when the record changes rarely and consumers must see updates immediately. Examples: `agent/.../allowed_hash_types`, `user/.../project_ids`. These tolerate "invalidate on any update" because updates are rare.

### `touch: true` after the cache-key fix

Once caches no longer depend on `cache_key_with_version`, audit each `touch: true`:

- **Remove** if its only purpose was cache invalidation. `HashcatStatus belongs_to :task` had `touch: true` purely for cache busting; removing it eliminated 6–10 cascading UPDATEs per status submission. Bypass-callback writes (`update_columns`) elsewhere on the same model are safe — they don't need touch.
- **Keep** if the parent uses `broadcasts_refreshes`. `HashItem belongs_to :hash_list, touch: true` is still needed because `HashList` broadcasts Turbo Stream refreshes on `updated_at` changes. After the cache-key fix, `touch: true` here has no cache side effects — it only drives UI refreshes.
- **Keep** if the parent renders a fragment cache keyed on it elsewhere. Audit before removing.

### Decision filter

When adding a new `Rails.cache.fetch`:

1. How often does the underlying data change? **More than once per minute** → ID+TTL. **Less than once per hour** → version-based is fine.
2. How stale can the response be? Pick `expires_in` accordingly; don't default to a number.
3. Does any ancestor in the `belongs_to` chain have `touch: true`? If yes, version-based keys will be invalidated by that ancestor's touches — be explicit about whether that's what you want.

### Anti-pattern to avoid

Embedding `cache_key_with_version` *plus* extra freshness probes in the key:

```ruby
# Bad — three queries just to build the key, plus version-based invalidation
"#{campaign.cache_key_with_version}/eta/#{attacks_freshness}-#{tasks_freshness}"
```

If you need finer-grained invalidation than `cache_key_with_version` provides, you almost certainly want ID+TTL with a short window instead. Building a custom version string from `maximum(:updated_at)` queries inverts the cache's purpose: you pay query cost on every read to maintain perfect freshness, when the caller asked for caching specifically to avoid that.
