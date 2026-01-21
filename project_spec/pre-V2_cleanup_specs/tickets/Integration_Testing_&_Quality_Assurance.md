# Integration Testing & Quality Assurance

## Overview

Comprehensive integration testing of all operational excellence features to ensure they work together correctly and meet Epic Brief success criteria. This ticket validates the complete system before deployment.

## Scope

**Included:**

- End-to-end system tests for all core flows
- Integration tests for real-time updates
- Performance testing for caching and queries
- Air-gapped deployment validation
- Test coverage verification
- Bug fixes discovered during testing

**Excluded:**

- Load testing (not needed for small customer base)
- Security penetration testing (separate concern)
- User acceptance testing (done by customers)

## Acceptance Criteria

### System Tests (End-to-End)

**Flow 1: Agent Fleet Monitoring**

- [ ] Test: View agent list, verify status badges, hash rates, error indicators
- [ ] Test: Click agent, verify detail page loads with tabs
- [ ] Test: Switch between tabs, verify content displays
- [ ] Test: Verify real-time updates (simulate agent status change)
- [ ] Test: Verify error indicator appears when agent has errors

**Flow 2: Campaign Progress Monitoring**

- [ ] Test: View campaign, verify progress bars and ETAs display
- [ ] Test: Verify current ETA and total ETA both shown
- [ ] Test: Click error indicator, verify modal opens with error details
- [ ] Test: Expand recent cracks, verify table displays
- [ ] Test: Verify real-time progress updates (simulate task completion)

**Flow 3: Task Detail Investigation**

- [ ] Test: View task detail, verify all information displays
- [ ] Test: Cancel task, verify state change and toast notification
- [ ] Test: Retry failed task, verify state change
- [ ] Test: Reassign task to compatible agent, verify success
- [ ] Test: Attempt reassign to incompatible agent, verify error
- [ ] Test: Download results CSV, verify content

**Flow 4: System Health Monitoring**

- [ ] Test: View system health page, verify all services shown
- [ ] Test: Verify health checks cached (second request faster)
- [ ] Test: Simulate service failure, verify error displayed
- [ ] Test: Click diagnostic links, verify navigation

**Flow 5: Campaign Creation Workflow**

- [ ] Test: Create campaign, verify redirect to add attack form
- [ ] Test: Verify toast notification on success

**Flow 6: Error Investigation**

- [ ] Test: Trigger error, verify error modal displays
- [ ] Test: View error log, verify errors listed
- [ ] Test: Verify error severity badges

**Flow 7: Loading & Feedback Patterns**

- [ ] Test: Verify skeleton loaders shown during page load
- [ ] Test: Verify toast notifications appear and auto-dismiss
- [ ] Test: Verify loading spinners on button actions

### Integration Tests

**Real-Time Updates:**

- [ ] Test: Agent status update broadcasts to list and detail pages
- [ ] Test: Campaign progress update broadcasts to campaign page
- [ ] Test: Task status update broadcasts to task page
- [ ] Test: Broadcasts don't disrupt user interaction (typing, scrolling)
- [ ] Test: Broadcasts don't reset Stimulus controller state (tabs)

**Caching:**

- [ ] Test: System health checks cached for 1 minute
- [ ] Test: Agent metrics cached for 30 seconds
- [ ] Test: Campaign ETAs cached for 1 minute
- [ ] Test: Recent cracks cached for 1 minute
- [ ] Test: Cache invalidation works correctly

**Authorization:**

- [ ] Test: Users can only access tasks in their projects
- [ ] Test: Admins can access all tasks
- [ ] Test: Unauthorized access returns 403 or redirects

### Performance Testing

- [ ] Test: Agent list loads in < 1 second with 50 agents
- [ ] Test: Campaign page loads in < 1 second with 20 attacks
- [ ] Test: System health checks complete in < 5 seconds
- [ ] Test: No N+1 queries in agent list, campaign list
- [ ] Test: Database indexes used for queries (check EXPLAIN)

### Air-Gapped Deployment Validation

- [ ] Validate all 10 checklist items from Epic Brief:
  - [ ] All CSS/JS assets bundled (no CDN references)
  - [ ] All fonts embedded or system fonts
  - [ ] All icons/images in asset pipeline
  - [ ] Docker compose works without Internet
  - [ ] All pages load without external requests
  - [ ] Asset precompilation successful
  - [ ] Health check endpoints work in isolated network
  - [ ] Agent API accessible from isolated agents
  - [ ] File uploads/downloads work with MinIO
  - [ ] Documentation accessible offline

### Test Coverage

- [ ] Overall test coverage > 80% (run with COVERAGE=true)
- [ ] All new controllers covered by request specs
- [ ] All new models methods covered by model specs
- [ ] All new components covered by component specs
- [ ] All new Stimulus controllers covered by JavaScript tests

### Bug Fixes

- [ ] All bugs discovered during testing fixed
- [ ] Regression tests added for fixed bugs
- [ ] No critical or high-severity bugs remaining

## Technical References

- **Epic Brief**: spec:50650885-e043-4e99-960b-672342fc4139/032658c4-43ca-40d4-adb4-682b6bca964a (Success Criteria, Testing acceptance criteria)
- **Core Flows**: spec:50650885-e043-4e99-960b-672342fc4139/c565e255-83e7-4d16-a4ec-d45011fa5cad (All flows)
- **Tech Plan**: spec:50650885-e043-4e99-960b-672342fc4139/f3c30678-d7af-45ab-a95b-0d0714906b9e (Testing Strategy)

## Dependencies

**Requires:**

- ticket:50650885-e043-4e99-960b-672342fc4139/[Database Schema & Model Extensions]
- ticket:50650885-e043-4e99-960b-672342fc4139/[Structured Logging & Error Handling]
- ticket:50650885-e043-4e99-960b-672342fc4139/[Agent Monitoring & Real-Time Updates]
- ticket:50650885-e043-4e99-960b-672342fc4139/[Campaign Progress & ETA Display]
- ticket:50650885-e043-4e99-960b-672342fc4139/[Task Management Actions]
- ticket:50650885-e043-4e99-960b-672342fc4139/[System Health Monitoring]
- ticket:50650885-e043-4e99-960b-672342fc4139/[UI Components & Loading States]

**Blocks:**

- ticket:50650885-e043-4e99-960b-672342fc4139/[User Guide Documentation] - Should document tested features

## Implementation Notes

- Run tests with: `just test` or `COVERAGE=true bundle exec rspec`
- System tests with: `just test-system` or `bundle exec rspec spec/system`
- Use `HEADLESS=false` to debug system tests visually
- Test air-gapped deployment in isolated Docker network
- Use existing test infrastructure (RSpec, Capybara, FactoryBot)
- Follow existing test patterns in file:spec/
- Aim for comprehensive coverage, not 100% coverage
- Focus on critical paths and edge cases

## Estimated Effort

**2-3 days** (comprehensive testing + bug fixes)
