# Structured Logging & Error Handling

## Overview

Implement comprehensive structured logging with Lograge and add error handling for Turbo Stream broadcasts. This ticket improves debuggability and system resilience.

## Scope

**Included:**

- Lograge gem installation and configuration
- Structured JSON logging for requests
- Custom log fields (user_id, agent_id, ip, request_id)
- Error handling for Turbo Stream broadcasts
- Logging for agent lifecycle events
- Logging for task state transitions (enhance existing)
- Logging for API requests/responses

**Excluded:**

- Log aggregation or analysis tools (out of scope)
- Real-time log viewing UI (use terminal/Sidekiq)
- Log rotation configuration (handled by Docker/system)

## Acceptance Criteria

### Lograge Configuration

- [ ] Lograge gem added to Gemfile
- [ ] Initializer created: `config/initializers/lograge.rb`
- [ ] Lograge enabled with JSON formatter
- [ ] Custom options include: user_id, agent_id, ip, request_id
- [ ] Logs output to STDOUT (Docker-friendly)

### Structured Logging Format

- [ ] Request logs in JSON format:
  ```json
  {
    "method": "GET",
    "path": "/agents/1",
    "status": 200,
    "duration": 45.2,
    "user_id": 123,
    "agent_id": null,
    "ip": "192.168.1.1",
    "request_id": "abc123",
    "timestamp": "2024-01-07T10:30:00Z"
  }
  ```

### Agent Lifecycle Logging

- [ ] Agent connect events logged (when agent first authenticates)
- [ ] Agent disconnect events logged (when agent goes offline)
- [ ] Agent heartbeat failures logged (when last_seen_at exceeds threshold)
- [ ] Logs include agent_id, state, last_seen_at, context

### Task State Transition Logging

- [ ] Enhance existing task transition logging (already partially implemented)
- [ ] Ensure all transitions logged with: task_id, agent_id, attack_id, old_state, new_state, reason
- [ ] Failed task transitions include error details

### API Request/Response Logging

- [ ] API requests logged with: method, path, agent_id, authentication status
- [ ] API responses logged with: status, duration, response_size
- [ ] Failed API requests logged with error details

### Broadcast Error Handling

- [ ] All Turbo Stream broadcasts wrapped in rescue blocks
- [ ] Broadcast failures logged with: model, target, error message, backtrace
- [ ] Broadcasts continue execution on error (don't raise)
- [ ] Error handling added to:
  - Agent status broadcasts
  - Attack progress broadcasts
  - Campaign broadcasts
  - Task broadcasts

### Testing

- [ ] Verify Lograge outputs JSON format
- [ ] Verify custom fields appear in logs
- [ ] Test broadcast error handling (mock broadcast failure)
- [ ] Verify logs don't expose sensitive data (passwords, tokens)

## Technical References

- **Tech Plan**: spec:50650885-e043-4e99-960b-672342fc4139/f3c30678-d7af-45ab-a95b-0d0714906b9e (Structured Logging section)
- **Epic Brief**: spec:50650885-e043-4e99-960b-672342fc4139/032658c4-43ca-40d4-adb4-682b6bca964a (Comprehensive Logging acceptance criteria)

## Dependencies

**None** - Can be implemented independently

## Implementation Notes

- Add Lograge to Gemfile: `gem 'lograge'`
- Configure in initializer, not environment files
- Test logging in development with `tail -f log/development.log`
- Use `Rails.logger.error` for errors, `Rails.logger.info` for lifecycle events
- Don't log sensitive data (passwords, API tokens, plaintext hashes in production)
- Broadcast error handling should be silent to users (log only)

## Estimated Effort

**1 day** (Lograge setup + broadcast error handling + testing)
