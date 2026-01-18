# System Health Monitoring

## Overview

Implement system health monitoring dashboard with service status checks, diagnostic links, and cache stampede prevention. This ticket delivers the system health monitoring flow from spec:50650885-e043-4e99-960b-672342fc4139/c565e255-83e7-4d16-a4ec-d45011fa5cad.

## Scope

**Included:**

- SystemHealthController with health check logic
- System health dashboard view
- Service health checks (PostgreSQL, Redis, MinIO, Sidekiq)
- Redis lock for cache stampede prevention
- SystemHealthCardComponent for service status display
- Diagnostic links to Sidekiq dashboard and logs
- Sidebar navigation link to system health

**Excluded:**

- Historical health data (no database persistence)
- Alerting or notifications (out of scope)
- Automated remediation (out of scope)
- Health check API endpoints (web UI only)

## Acceptance Criteria

### SystemHealthController

- [ ] Controller created: app/controllers/system_health_controller.rb
- [ ] Action: `index` displays health dashboard
- [ ] Authorization: requires authentication, uses CanCanCan
- [ ] Health checks cached with 1-minute TTL
- [ ] Redis lock prevents cache stampede (only one request runs checks)
- [ ] Concurrent requests return cached value or "checking" status

### Service Health Checks

**PostgreSQL:**

- [ ] Check: `ActiveRecord::Base.connection.execute("SELECT 1")`
- [ ] Returns: status (:healthy/:unhealthy), latency (ms)
- [ ] Logs errors on failure

**Redis:**

- [ ] Check: `Redis.current.ping`
- [ ] Returns: status (:healthy/:unhealthy), latency (ms)
- [ ] Logs errors on failure

**MinIO:**

- [ ] Check: `ActiveStorage::Blob.service.exist?("health_check")`
- [ ] Returns: status (:healthy/:unhealthy), latency (ms)
- [ ] Logs errors on failure

**Sidekiq:**

- [ ] Check: `Sidekiq::Stats.new`
- [ ] Returns: status (:healthy/:unhealthy), workers count, queues count, enqueued jobs
- [ ] Logs errors on failure

### Redis Lock Implementation

- [ ] Lock key: `system_health_check_lock`
- [ ] Lock acquired with: `Redis.current.set(lock_key, "locked", nx: true, ex: 10)`
- [ ] Lock expires after 10 seconds (prevents deadlock)
- [ ] If lock not acquired, wait 100ms and return cached value
- [ ] If no cached value, return "checking" status for all services
- [ ] Lock released after health checks complete

### System Health Dashboard

- [ ] Grid layout with 4 service cards (one per service)

- [ ] Each card shows:

  - Service name (PostgreSQL, Redis, MinIO, Sidekiq)
  - Status indicator (green checkmark or red X)
  - Latency (if healthy)
  - Error message (if unhealthy)
  - Additional metrics (for Sidekiq: workers, queues, enqueued)

- [ ] Diagnostic links section:

  - Link to Sidekiq dashboard (existing `/sidekiq` route)
  - Link to Rails logs (informational, view in terminal)

- [ ] Manual refresh button (optional, cache auto-expires)

- [ ] Skeleton loader shown while loading

- [ ] Empty state if health checks fail to run

### Navigation

- [ ] Sidebar link added: "System Health" or "Monitoring"
- [ ] Link visible to all authenticated users
- [ ] Link highlights when active (current page)

### Components

- [ ] `SystemHealthCardComponent` created with:

  - Service name display
  - Status badge (success/danger)
  - Status icon (check-circle/x-circle)
  - Latency display (if available)
  - Error message display (if unhealthy)

- [ ] Component follows existing Railsboot patterns

- [ ] Component tested with component specs

### Testing

- [ ] Request spec: GET /system_health, verify response
- [ ] Request spec: Verify caching works (second request uses cache)
- [ ] Request spec: Verify Redis lock prevents concurrent checks
- [ ] System test: View system health page, verify all services shown
- [ ] System test: Mock service failure, verify error displayed
- [ ] Component test for SystemHealthCardComponent

## Technical References

- **Core Flows**: spec:50650885-e043-4e99-960b-672342fc4139/c565e255-83e7-4d16-a4ec-d45011fa5cad (Flow 4: System Health Monitoring)
- **Tech Plan**: spec:50650885-e043-4e99-960b-672342fc4139/f3c30678-d7af-45ab-a95b-0d0714906b9e (SystemHealthController, Redis Lock, Component Architecture)

## Dependencies

**Requires:**

- ticket:50650885-e043-4e99-960b-672342fc4139/[UI Components & Loading States] - Needs SystemHealthCardComponent

**Blocks:**

- None (other features can be implemented in parallel)

## Implementation Notes

- Create new controller: app/controllers/system_health_controller.rb
- Create new view: app/views/system_health/index.html.erb
- Add route: `resource :system_health, only: [:index]`
- Update sidebar partial: file:app/views/partials/\_sidebar.html.erb
- Test Redis lock with concurrent requests (use threads in test)
- Ensure health checks work in air-gapped environment
- Consider adding timeout to health checks (5 seconds) to prevent hanging

## Estimated Effort

**1-2 days** (controller + health checks + Redis lock + view + tests)
