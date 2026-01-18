# Production Deployment & Monitoring

## Overview

Deploy operational excellence features to production and establish monitoring for the new capabilities. This ticket ensures smooth rollout to existing customers.

## Scope

**Included:**

- Production deployment preparation
- Database migration execution
- Cache warming strategy
- Rollback plan
- Post-deployment monitoring
- Customer communication

**Excluded:**

- New customer onboarding (separate process)
- Infrastructure changes (Docker setup already exists)
- Performance tuning (addressed in testing ticket)

## Acceptance Criteria

### Pre-Deployment

- [ ] All tests passing (from Integration Testing ticket)
- [ ] Code review completed (self-review or peer review)
- [ ] Changelog updated with new features
- [ ] Release notes prepared for customers
- [ ] Rollback plan documented

### Database Migrations

- [ ] Migrations tested in staging/development

- [ ] Migration execution plan:

  1. Backup database
  2. Run migrations: `bin/rails db:migrate`
  3. Verify schema changes
  4. Warm caches (visit key pages)

- [ ] Rollback plan if migrations fail:

  1. Rollback migrations: `bin/rails db:rollback STEP=2`
  2. Restore from backup if needed
  3. Investigate and fix issues

### Deployment Process

- [ ] Pull latest code: `git pull origin main`
- [ ] Build Docker image: `docker compose build`
- [ ] Run migrations: `docker compose run web bin/rails db:migrate`
- [ ] Restart services: `docker compose up -d`
- [ ] Verify health checks: Visit `/system_health`
- [ ] Smoke test critical flows:
  - View agent list
  - View campaign progress
  - Create test campaign
  - Check system health

### Cache Warming

- [ ] Visit key pages to warm caches:

  - Agent list (warms agent metrics cache)
  - Campaign list (warms campaign ETA cache)
  - System health (warms health check cache)

- [ ] Verify caches populated (check Redis or Rails.cache)

### Post-Deployment Monitoring

- [ ] Monitor logs for errors (first 24 hours)
- [ ] Check Sidekiq dashboard for failed jobs
- [ ] Verify Turbo Stream broadcasts working (check WebSocket connections)
- [ ] Monitor database performance (slow query log)
- [ ] Check system health dashboard shows all services healthy

### Customer Communication

- [ ] Release notes sent to customers:

  - New features: agent monitoring, campaign progress, task management, system health
  - Breaking changes: None expected
  - Action required: None (automatic upgrade)

- [ ] Support plan for first week:

  - Monitor for customer issues
  - Quick response to bug reports
  - Gather feedback on new features

### Rollback Criteria

If any of these occur, rollback immediately:

- [ ] Database migrations fail
- [ ] Critical functionality broken (can't create campaigns, agents offline)
- [ ] Performance degradation (page load > 5 seconds)
- [ ] Data corruption or loss
- [ ] Security vulnerability discovered

### Success Metrics

After 1 week in production:

- [ ] No critical bugs reported
- [ ] System health dashboard shows all services healthy
- [ ] Turbo Stream broadcasts working (no WebSocket errors in logs)
- [ ] Customer feedback positive or neutral
- [ ] Support burden reduced (fewer troubleshooting requests)

## Technical References

- **Epic Brief**: spec:50650885-e043-4e99-960b-672342fc4139/032658c4-43ca-40d4-adb4-682b6bca964a (Success Criteria)
- **Tech Plan**: spec:50650885-e043-4e99-960b-672342fc4139/f3c30678-d7af-45ab-a95b-0d0714906b9e (Deployment Considerations)

## Dependencies

**Requires:**

- ticket:50650885-e043-4e99-960b-672342fc4139/[Integration Testing & Quality Assurance] - All tests must pass
- ticket:50650885-e043-4e99-960b-672342fc4139/[User Guide Documentation] - Documentation ready for customers

**Blocks:**

- None (final ticket)

## Implementation Notes

- Deploy during low-usage window (if possible)
- Have rollback plan ready before starting
- Monitor logs in real-time during deployment
- Test in staging environment first (if available)
- Keep customers informed of deployment window
- Document any issues encountered for future deployments
- Verify air-gapped deployment works (test in isolated network)

## Estimated Effort

**1 day** (deployment + monitoring + customer communication)
