---
status: pending
priority: p2
issue_id: '010'
tags: [code-review, performance, infrastructure, scalability]
dependencies: []
---

# Sidekiq-Aware Connection Pool Sizing

## Problem Statement

The database pool formula `RAILS_MAX_THREADS * 2` is shared between Puma and Sidekiq via `database.yml`. If `RAILS_MAX_THREADS` is set to 5 (Puma default) for the Sidekiq container, the pool drops to 10 — exactly matching Sidekiq concurrency with zero headroom. Under burst conditions (10+ agents submitting cracks simultaneously), `ActiveRecord::ConnectionTimeoutError` will surface.

## Findings

- **Source**: performance-oracle agent
- **Evidence**: `config/database.yml:33`, `config/sidekiq.yml:6` (concurrency 10)
- **Impact**: Connection pool exhaustion under sustained agent load

## Proposed Solutions

### Option A: Sidekiq pool initializer (Recommended)

- Add `config/initializers/sidekiq_db_pool.rb` that sets pool = concurrency + 5 when running as Sidekiq server
- **Effort**: Small
- **Risk**: Low

### Option B: Document RAILS_MAX_THREADS requirement

- Document that Sidekiq containers must set `RAILS_MAX_THREADS >= Sidekiq concurrency / 2`
- **Effort**: Trivial
- **Risk**: Relies on operator knowledge

## Acceptance Criteria

- [ ] Sidekiq pool size automatically matches concurrency + headroom
- [ ] No `ConnectionTimeoutError` under 10-agent sustained load
