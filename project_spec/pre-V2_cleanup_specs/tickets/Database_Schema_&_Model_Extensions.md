# Database Schema & Model Extensions

## Overview

Implement database migrations and model extensions to support operational monitoring features. This ticket establishes the data foundation for agent metrics caching, performance optimization, and ETA calculations.

## Scope

**Included:**

- Database migrations for performance indexes
- Database migration for cached agent metrics columns
- Agent model methods for metrics display
- HashcatStatus callback to update agent metrics
- Campaign model methods for ETA calculation (current + total)
- HashList model methods for recent cracks
- Task state machine retry event

**Excluded:**

- UI components (separate ticket)
- Controller actions (separate ticket)
- Turbo Stream broadcasts (separate ticket)

## Acceptance Criteria

### Migrations

- [ ] Migration created: `AddPerformanceIndexes`

  - Index on `hash_items.cracked_time`
  - Index on `agent_errors.created_at`
  - Index on `hashcat_statuses.time`
  - Composite index on `tasks(agent_id, state)`

- [ ] Migration created: `AddCachedMetricsToAgents`

  - Column: `current_hash_rate` (decimal, precision: 20, scale: 2)
  - Column: `current_temperature` (integer)
  - Column: `current_utilization` (integer)
  - Column: `metrics_updated_at` (datetime, indexed)

- [ ] Migrations run successfully in development and test environments

- [ ] Schema.rb updated with new columns and indexes

### Model Extensions

**Agent Model:**

- [ ] Method `hash_rate_display` returns formatted hash rate ("—", "0 H/s", or "X.X MH/s")
- [ ] Cached metrics columns populated when HashcatStatus is created

**HashcatStatus Model:**

- [ ] Callback `after_create_commit :update_agent_metrics` implemented
- [ ] Callback updates Agent metrics only if status is `:running`
- [ ] Callback throttles updates (only if metrics_updated_at > 30 seconds ago)
- [ ] Callback rescues errors and logs failures

**Campaign Model:**

- [ ] Method `current_eta` returns ETA for running attacks (cached, 1-minute TTL)
- [ ] Method `total_eta` returns ETA for all incomplete attacks (cached, 1-minute TTL)
- [ ] Method `calculate_current_eta` returns max ETA of running attacks
- [ ] Method `calculate_total_eta` estimates total campaign completion time

**HashList Model:**

- [ ] Method `recent_cracks(limit: 100)` returns hashes cracked in last 24 hours (cached, 1-minute TTL)
- [ ] Method `recent_cracks_count` returns count of recent cracks (cached, 1-minute TTL)
- [ ] Methods use indexed query on `cracked_time`

**Task Model:**

- [ ] State machine event `retry` added with `failed → pending` transition
- [ ] Callback `after_transition on: :retry` logs retry event
- [ ] Callback increments `retry_count`
- [ ] Callback clears `last_error`

### Testing

- [ ] Model specs for new methods (Agent, Campaign, HashList, Task)
- [ ] State machine specs for retry event
- [ ] Callback specs for HashcatStatus → Agent metrics update
- [ ] Migration specs verify indexes created

## Technical References

- **Tech Plan**: spec:50650885-e043-4e99-960b-672342fc4139/f3c30678-d7af-45ab-a95b-0d0714906b9e (Data Model section)
- **Epic Brief**: spec:50650885-e043-4e99-960b-672342fc4139/032658c4-43ca-40d4-adb4-682b6bca964a (Core Stability acceptance criteria)

## Dependencies

**None** - This is the foundation ticket that other tickets depend on.

## Implementation Notes

- Use Rails generators for migrations: `bin/rails generate migration AddPerformanceIndexes`
- Follow existing model patterns (caching with `cache_key_with_version`, error handling with rescue)
- Test migrations in development before committing
- Ensure callbacks don't create N+1 queries (use `update_columns` for direct updates)
- Add database indexes before adding model methods (performance optimization first)

## Estimated Effort

**1-2 days** (migrations + model methods + tests)
