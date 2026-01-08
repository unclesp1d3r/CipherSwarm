# Logging Guide for CipherSwarm

## Overview

CipherSwarm uses structured logging to provide comprehensive observability across all components of the system. This guide explains the logging infrastructure, formats, and best practices for debugging and monitoring.

### Purpose

Structured logging in CipherSwarm serves several key purposes:

- **Debugging**: Quickly identify and diagnose issues in development and production
- **Monitoring**: Track system health, performance, and agent behavior
- **Auditing**: Maintain records of important state changes and user actions
- **Integration**: Compatible with log aggregation services (ELK, Datadog, Splunk, etc.)

### Benefits

- **Consistent Format**: All logs use predictable, parseable formats with `[LogType]` prefixes
- **Rich Context**: Logs include relevant IDs, timestamps, and contextual information
- **Sensitive Data Protection**: Automatic filtering of passwords, tokens, and plaintext hashes
- **Performance**: Minimal overhead with efficient JSON serialization
- **Searchability**: Easy to query and filter logs by type and context

## Lograge Configuration

CipherSwarm uses [Lograge](https://github.com/roidrage/lograge) to transform Rails request logs into structured JSON format.

### Enabled Environments

- ✅ **Production**: Fully enabled for production monitoring
- ✅ **Development**: Enabled to match production behavior
- ❌ **Test**: Disabled to avoid test pollution

### JSON Format Structure

Each HTTP request generates a single-line JSON log entry:

```json
{
  "method": "GET",
  "path": "/campaigns/1",
  "format": "html",
  "controller": "CampaignsController",
  "action": "show",
  "status": 200,
  "duration": 45.23,
  "view": 32.1,
  "db": 8.45,
  "allocations": 15234,
  "host": "localhost:3000",
  "request_id": "abc123...",
  "user_agent": "Mozilla/5.0...",
  "ip": "192.168.1.100",
  "time": "2026-01-07T21:00:00.000Z",
  "user_id": 5,
  "agent_id": null,
  "task_id": null,
  "attack_id": null
}
```

### Custom Payload Fields

Lograge is configured to extract additional context from each request:

- **user_id**: Extracted from Devise `current_user` for web UI requests
- **agent_id**: Extracted from `@agent`, `params[:agent_id]`, or authorization token
- **task_id**: Extracted from `@task` or `params[:task_id]`
- **attack_id**: Extracted from `@attack`, `@task.attack`, or `params[:attack_id]`

### Ignored Paths

The following paths are filtered out to reduce log noise:

- **Health Checks**: `Rails::HealthController#show` (no value in monitoring)
- **Assets**: `/assets/*` paths (handled by CDN/web server in production)

### Configuration File

Location: [config/initializers/lograge.rb](../../config/initializers/lograge.rb)

```ruby
Rails.application.configure do
  config.lograge.enabled = Rails.env.production? || Rails.env.development?
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_payload do |controller|
    {
      host: controller.request.host,
      request_id: controller.request.request_id,
      user_agent: controller.request.user_agent,
      ip: controller.request.remote_ip,
      time: Time.current,
      user_id: controller.try(:current_user)&.id,
      agent_id: controller.instance_variable_get(:@agent)&.id ||
                controller.params[:agent_id] ||
                controller.request.headers["Authorization"]&.split&.last&.then { |token| Agent.find_by(token: token)&.id },
      task_id: controller.instance_variable_get(:@task)&.id || controller.params[:task_id],
      attack_id: controller.instance_variable_get(:@attack)&.id ||
                 controller.instance_variable_get(:@task)&.attack_id ||
                 controller.params[:attack_id]
    }
  end
end
```

## Log Types and Formats

CipherSwarm uses four main log type prefixes to categorize different logging scenarios.

### [APIRequest] Logs

Tracks the lifecycle of API requests from start to completion.

#### START Log

Logged at the beginning of each API request (before authentication).

**Format:**

```
[APIRequest] START - Agent {agent_id} - {method} {path} - {timestamp}
```

**Example:**

```
[APIRequest] START - Agent 42 - POST /api/v1/client/tasks/123/submit_status - 2026-01-07T21:00:00.000Z
[APIRequest] START - Agent unknown - GET /api/v1/client/configuration - 2026-01-07T21:00:05.000Z
```

**Fields:**

- `agent_id`: Authenticated agent ID or "unknown" if authentication hasn't occurred yet
- `method`: HTTP method (GET, POST, PATCH, DELETE)
- `path`: Request path
- `timestamp`: ISO 8601 timestamp

#### COMPLETE Log

Logged after each API request completes (after response is rendered).

**Format:**

```
[APIRequest] COMPLETE - Agent {agent_id} - {method} {path} - Status {status} - Duration {duration}ms - {timestamp}
```

**Example:**

```
[APIRequest] COMPLETE - Agent 42 - POST /api/v1/client/tasks/123/submit_status - Status 204 - Duration 45.23ms - 2026-01-07T21:00:00.050Z
[APIRequest] COMPLETE - Agent unknown - GET /api/v1/client/configuration - Status 401 - Duration 12.34ms - 2026-01-07T21:00:05.015Z
```

**Fields:**

- `agent_id`: Authenticated agent ID or "unknown" for failed authentication
- `method`: HTTP method
- `path`: Request path
- `status`: HTTP response status code
- `duration`: Request duration in milliseconds (calculated from START time)
- `timestamp`: ISO 8601 timestamp

#### When They Appear

- **START**: Before `authenticate_agent` callback in `BaseController`
- **COMPLETE**: After `update_last_seen` callback in `BaseController`
- **Frequency**: One START + one COMPLETE log per API request

#### Implementation

Location: [app/controllers/api/v1/base_controller.rb](../../app/controllers/api/v1/base_controller.rb)

```ruby
before_action :log_api_request_start
after_action :log_api_request_complete

def log_api_request_start
  @api_request_start_time = Time.current
  agent_id = @agent&.id || "unknown"
  Rails.logger.info("[APIRequest] START - Agent #{agent_id} - #{request.method} #{request.path} - #{@api_request_start_time}")
rescue StandardError => e
  Rails.logger.error("Failed to log API request start: #{e.message}")
end

def log_api_request_complete
  agent_id = @agent&.id || "unknown"
  duration_ms = if @api_request_start_time
                  ((Time.current - @api_request_start_time) * 1000).round(2)
                else
                  "N/A"
                end
  Rails.logger.info("[APIRequest] COMPLETE - Agent #{agent_id} - #{request.method} #{request.path} - Status #{response.status} - Duration #{duration_ms}ms - #{Time.current}")
rescue StandardError => e
  Rails.logger.error("Failed to log API request completion: #{e.message}")
end
```

### [APIError] Logs

Tracks errors that occur during API request processing.

#### Error Types

| Error Type                    | Description                        | HTTP Status               |
| ----------------------------- | ---------------------------------- | ------------------------- |
| `JSON_PARSE_ERROR`            | Invalid JSON in request body       | 400 Bad Request           |
| `VALIDATION_ERROR`            | Model validation failed            | 422 Unprocessable Content |
| `DUPLICATE_RECORD`            | Unique constraint violation        | 409 Conflict              |
| `UNHANDLED_ERROR`             | Unexpected exception               | 500 Internal Server Error |
| `TASK_ABANDON_FAILED`         | Failed to abandon task             | 422                       |
| `TASK_ACCEPT_FAILED`          | Failed to accept task              | 422                       |
| `ATTACK_ACCEPT_FAILED`        | Failed to accept attack            | 422                       |
| `TASK_EXHAUST_FAILED`         | Failed to exhaust task             | 422                       |
| `ATTACK_EXHAUST_FAILED`       | Failed to exhaust attack           | 422                       |
| `TASK_ALREADY_COMPLETED`      | Task is already completed          | 422                       |
| `HASH_NOT_FOUND`              | Hash not found in hash list        | 404                       |
| `HASH_UPDATE_FAILED`          | Failed to update hash item         | 422                       |
| `TASK_ACCEPT_CRACK_FAILED`    | Failed to accept crack             | 422                       |
| `GUESS_NOT_FOUND`             | Guess parameters missing           | 422                       |
| `DEVICE_STATUSES_NOT_FOUND`   | Device statuses missing            | 422                       |
| `STATUS_SAVE_FAILED`          | Failed to save status              | 422                       |
| `TASK_ACCEPT_STATUS_FAILED`   | Failed to accept status            | 422                       |
| `AGENT_UPDATE_FAILED`         | Failed to update agent             | 422                       |
| `BENCHMARK_SUBMISSION_FAILED` | Failed to submit benchmarks        | 422                       |
| `ERROR_RECORD_SAVE_FAILED`    | Failed to save error record        | 422                       |
| `ATTACK_NOT_FOUND`            | Attack not found                   | 404                       |
| `MISSING_VERSION`             | Version parameter missing          | 400                       |
| `MISSING_OS`                  | Operating system parameter missing | 400                       |
| `INVALID_VERSION_FORMAT`      | Invalid version format             | 400                       |

#### Format

**General:**

```
[APIError] {ERROR_TYPE} - Agent {agent_id} - {method} {path} - Error: {message} - {timestamp}
```

**With Context:**

```
[APIError] {ERROR_TYPE} - Agent {agent_id} - Task {task_id} - Errors: {error_messages} - {timestamp}
[APIError] {ERROR_TYPE} - Agent {agent_id} - Attack {attack_id} - Errors: {error_messages} - {timestamp}
```

**With Backtrace (UNHANDLED_ERROR):**

```
[APIError] UNHANDLED_ERROR - Agent {agent_id} - {method} {path} - Error: {error_class} - {error_message} - Backtrace: {first_5_lines} - {timestamp}
```

#### Examples

```
[APIError] JSON_PARSE_ERROR - Agent 42 - POST /api/v1/client/tasks/123/submit_status - Error: unexpected token at '{invalid json}' - 2026-01-07T21:00:00.000Z

[APIError] VALIDATION_ERROR - Agent 42 - POST /api/v1/client/agents/42 - Model: Agent - Errors: Name can't be blank - 2026-01-07T21:00:00.000Z

[APIError] TASK_ACCEPT_FAILED - Agent 42 - Task 123 - Errors: State transition failed - 2026-01-07T21:00:00.000Z

[APIError] UNHANDLED_ERROR - Agent 42 - GET /api/v1/client/tasks/new - Error: NoMethodError - undefined method `foo' for nil:NilClass - Backtrace: app/controllers/api/v1/client/tasks_controller.rb:45:in `new'\n... - 2026-01-07T21:00:00.000Z
```

#### When They Appear

- When `rescue_from` blocks catch exceptions in `BaseController`
- When specific error conditions are detected in controller actions
- For all API errors that return 4xx or 5xx status codes

#### Implementation

Errors are caught and logged in [app/controllers/api/v1/base_controller.rb](../../app/controllers/api/v1/base_controller.rb) and individual controller actions.

### [AgentLifecycle] Logs

Tracks important agent state transitions and lifecycle events.

#### Event Types

| Event                          | Description                                    | State Transition      |
| ------------------------------ | ---------------------------------------------- | --------------------- |
| `connect`                      | Agent first connects and activates             | `pending → active`    |
| `disconnect`                   | Agent is manually deactivated                  | `{any} → stopped`     |
| `shutdown`                     | Agent explicitly shuts down                    | `{any} → offline`     |
| `shutdown_success`             | Shutdown completed successfully                | N/A                   |
| `shutdown_failed`              | Shutdown failed with errors                    | N/A                   |
| `reconnect`                    | Agent comes back online after being offline    | `offline → active`    |
| `heartbeat_timeout`            | Agent hasn't checked in within threshold       | `{any} → offline`     |
| `heartbeat_threshold_exceeded` | Agent's last_seen_at exceeds offline threshold | N/A (warning)         |
| `heartbeat_failed`             | Heartbeat state transition failed              | N/A                   |
| `benchmark_complete`           | Agent completes benchmark submission           | `{any} → benchmarked` |
| `benchmark_stale`              | Agent's benchmarks are too old                 | N/A (warning)         |

#### Formats

**Connect:**

```text
[AgentLifecycle] connect: agent_id={id} state_change={old}->{new} last_seen_at={time} ip={ip} timestamp={time}
```

**Disconnect:**

```text
[AgentLifecycle] disconnect: agent_id={id} state_change={old}->{new} last_seen_at={time} ip={ip} timestamp={time}
```

**Shutdown:**

```text
[AgentLifecycle] shutdown: agent_id={id} state_change={old}->{new} running_tasks_abandoned={count} timestamp={time}
[AgentLifecycle] shutdown_success: agent_id={id} state={state} timestamp={time}
[AgentLifecycle] shutdown_failed: agent_id={id} state={state} errors={error_messages} timestamp={time}
```

**Reconnect:**

```text
[AgentLifecycle] reconnect: agent_id={id} state_change={old}->{new} last_seen_at={time} ip={ip} timestamp={time}
```

**Heartbeat Timeout:**

```text
[AgentLifecycle] heartbeat_timeout: agent_id={id} state_change={old}->{new} last_seen_at={time} threshold={config} timestamp={time}
[AgentLifecycle] heartbeat_threshold_exceeded: agent_id={id} last_seen_at={time} threshold={config} timestamp={time}
```

**Benchmark Complete:**

```text
[AgentLifecycle] benchmark_complete: agent_id={id} state_change={old}->{new} benchmark_count={count} timestamp={time}
```

#### Examples

```text
[AgentLifecycle] connect: agent_id=42 state_change=pending->active last_seen_at=2026-01-07T21:00:00.000Z ip=192.168.1.100 timestamp=2026-01-07T21:00:00.000Z

[AgentLifecycle] shutdown: agent_id=42 state_change=active->offline running_tasks_abandoned=3 timestamp=2026-01-07T21:05:00.000Z
[AgentLifecycle] shutdown_success: agent_id=42 state=offline timestamp=2026-01-07T21:05:00.100Z

[AgentLifecycle] reconnect: agent_id=42 state_change=offline->active last_seen_at=2026-01-07T21:10:00.000Z ip=192.168.1.100 timestamp=2026-01-07T21:10:00.000Z

[AgentLifecycle] heartbeat_timeout: agent_id=42 state_change=active->offline last_seen_at=2026-01-07T19:00:00.000Z threshold=3600 timestamp=2026-01-07T21:00:00.000Z

[AgentLifecycle] benchmark_complete: agent_id=42 state_change=active->benchmarked benchmark_count=15 timestamp=2026-01-07T21:00:00.000Z
```

#### When They Appear

- When agent state transitions occur via state machine callbacks
- After important agent operations complete
- When timeout thresholds are exceeded

#### Implementation

Location: [app/models/agent.rb](../../app/models/agent.rb)

Lifecycle events are logged in state machine `after_transition` callbacks:

```ruby
state_machine :state do
  after_transition on: :shutdown do |agent, transition|
    # Log shutdown event
  end

  after_transition on: :activate do |agent, transition|
    # Log connect event
  end

  # ... etc
end
```

### [BroadcastError] Logs

Tracks failures in Turbo Stream broadcasts to prevent application crashes.

#### Format

```
[BroadcastError] Model: {model_name} - Record ID: {record_id} - Error: {error_message}
Backtrace:
{first_5_backtrace_lines}
```

#### Example

```
[BroadcastError] Model: Agent - Record ID: 42 - Error: Connection refused - connect(2) for "localhost" port 6379
Backtrace:
/path/to/redis/client.rb:123:in `connect'
/path/to/turbo/broadcastable.rb:45:in `broadcast_refresh'
app/models/agent.rb:234:in `block in <class:Agent>'
app/controllers/agents_controller.rb:67:in `update'
...
```

#### When They Appear

- When Turbo Stream broadcasts fail (Redis connection issues, network problems, etc.)
- During model updates that trigger `broadcasts_refreshes` or similar broadcasts
- Should be rare in production but critical to catch

#### Affected Models

Models that include `SafeBroadcasting` concern:

- Agent
- Task
- Attack
- Campaign
- User
- AgentError
- HashList
- Project
- HashcatBenchmark
- WordList
- RuleList
- MaskList

#### Implementation

Location: [app/models/concerns/safe_broadcasting.rb](../../app/models/concerns/safe_broadcasting.rb)

```ruby
module SafeBroadcasting
  extend ActiveSupport::Concern

  included do
    after_commit :safe_broadcast_refresh, if: :previously_new_record?
    after_update_commit :safe_broadcast_update
  end

  private

  def safe_broadcast(method)
    send(method)
  rescue StandardError => e
    Rails.logger.error("[BroadcastError] Model: #{self.class.name} - Record ID: #{id} - Error: #{e.message}")
    Rails.logger.error("Backtrace:\n#{e.backtrace.first(5).join("\n")}")
  end

  def safe_broadcast_refresh
    safe_broadcast(:broadcast_refresh)
  end

  def safe_broadcast_update
    safe_broadcast(:broadcast_update)
  end
end
```

## Sensitive Data Filtering

CipherSwarm automatically filters sensitive parameters from all logs to protect user data.

### Filtered Parameters

The following parameter names (or partial matches) are filtered:

| Pattern       | Matches                      | Examples                                                |
| ------------- | ---------------------------- | ------------------------------------------------------- |
| `passw`       | Any password field           | `password`, `password_confirmation`, `current_password` |
| `email`       | Email addresses              | `email`, `user_email`, `contact_email`                  |
| `secret`      | Secret values                | `secret`, `secret_key`, `oauth_secret`                  |
| `token`       | Authentication tokens        | `token`, `auth_token`, `api_token`, `csrf_token`        |
| `_key`        | API keys and encryption keys | `api_key`, `encryption_key`, `private_key`              |
| `crypt`       | Encrypted values             | `encrypted_password`, `crypt`                           |
| `salt`        | Password salts               | `salt`, `password_salt`                                 |
| `certificate` | SSL certificates             | `certificate`, `ssl_certificate`                        |
| `otp`         | One-time passwords           | `otp`, `otp_secret`                                     |
| `ssn`         | Social security numbers      | `ssn`, `social_security_number`                         |
| `cvv`         | Credit card CVV codes        | `cvv`, `cvv2`, `cvc`                                    |
| `cvc`         | Credit card CVC codes        | `cvc`                                                   |
| `plain_text`  | Cracked hash plaintext       | `plain_text`                                            |
| `hash_value`  | Full hash values             | `hash_value`                                            |

### How Filtering Works

Rails' built-in `ActiveSupport::ParameterFilter` automatically replaces filtered values with `[FILTERED]` in logs.

**Before filtering:**

```json
{
  "user": {
    "email": "user@example.com",
    "password": "supersecret123",
    "name": "John Doe"
  },
  "agent": {
    "token": "abc123xyz789"
  }
}
```

**After filtering:**

```json
{
  "user": {
    "email": "[FILTERED]",
    "password": "[FILTERED]",
    "name": "John Doe"
  },
  "agent": {
    "token": "[FILTERED]"
  }
}
```

### Configuration

Location: [config/initializers/filter_parameter_logging.rb](../../config/initializers/filter_parameter_logging.rb)

```ruby
Rails.application.config.filter_parameters += %i[
  passw email secret token _key crypt salt certificate otp ssn cvv cvc plain_text hash_value
]
```

### Verification

To verify sensitive data is filtered:

1. **Development Testing:**

   ```bash
   just dev
   # Make requests with sensitive data
   # Search logs for actual values (should not appear)
   grep -r "supersecret123" log/
   # Should return no results
   ```

2. **Log Review:**

   - Review logs after authentication requests
   - Review logs after crack submissions
   - Verify passwords, tokens, and plaintext hashes show as `[FILTERED]`

3. **Automated Testing:**

   - RSpec tests verify filtering is configured
   - Integration tests verify sensitive data doesn't appear in log output

## Development Testing

### Enabling Lograge in Development

Lograge is already enabled in development to match production behavior. No configuration changes needed.

### Viewing Logs

Start the development server:

```bash
just dev
```

Logs will appear in the terminal with JSON format (single line per request).

### Testing Specific Scenarios

#### Test API Request Logging

```bash
# In terminal 1: Start server
just dev

# In terminal 2: Make API requests
curl -H "Authorization: Bearer YOUR_AGENT_TOKEN" \
  http://localhost:3000/api/v1/client/configuration

# Check logs for:
# [APIRequest] START - Agent X - GET /api/v1/client/configuration
# [APIRequest] COMPLETE - Agent X - GET /api/v1/client/configuration - Status 200 - Duration XXms
```

#### Test Agent Lifecycle Logging

```bash
# Create agent and trigger state transitions
rails console

agent = Agent.create!(name: "Test Agent", ...)
agent.activate  # Check for [AgentLifecycle] connect log
agent.shutdown  # Check for [AgentLifecycle] shutdown log
```

#### Test Broadcast Error Handling

```bash
# Temporarily stop Redis
brew services stop redis

# Update a model
rails console
agent = Agent.first
agent.update(name: "New Name")

# Check for [BroadcastError] log (application should continue working)

# Restart Redis
brew services start redis
```

### Verifying Sensitive Data Filtering

```bash
# Make request with sensitive data
curl -X POST http://localhost:3000/api/v1/client/tasks/123/submit_crack \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"hash": "abc123", "plain_text": "password123"}'

# Search logs for plaintext (should not appear)
grep "password123" log/development.log
# Should return no results
```

## Production Monitoring

### Log Aggregation Services

CipherSwarm's structured JSON logs are compatible with:

- **ELK Stack** (Elasticsearch, Logstash, Kibana)
- **Datadog**
- **Splunk**
- **Papertrail**
- **Loggly**
- **CloudWatch** (AWS)
- **Stackdriver** (GCP)

### Common Queries

#### Find All API Errors

```
[APIError]
```

#### Find Agent Connection Issues

```
[AgentLifecycle] AND (heartbeat_timeout OR disconnect OR shutdown_failed)
```

#### Find Broadcast Failures

```text
[BroadcastError]
```

#### Find Slow API Requests

```text
[APIRequest] COMPLETE AND Duration > 1000ms
```

#### Find Authentication Failures

```text
[APIRequest] COMPLETE AND Status 401
```

#### Find Specific Agent Activity

```text
[APIRequest] AND "Agent 42"
```

```text
[AgentLifecycle] AND "agent_id=42"
```

### Recommended Alerts

#### Critical Alerts

- **Unhandled Errors**: Any `[APIError] UNHANDLED_ERROR` log
- **Agent Shutdown Failures**: Any `[AgentLifecycle] shutdown_failed` log
- **High Error Rate**: More than 10 `[APIError]` logs per minute

#### Warning Alerts

- **Broadcast Failures**: More than 5 `[BroadcastError]` logs per minute
- **Agent Timeouts**: More than 5 `[AgentLifecycle] heartbeat_timeout` logs per hour
- **Authentication Failures**: More than 20 failed auth attempts per minute (potential attack)

#### Performance Alerts

- **Slow API Requests**: Average API duration > 500ms over 5 minutes
- **High API Volume**: More than 1000 API requests per minute (capacity planning)

### Recommended Dashboards

#### API Performance Dashboard

- API request volume (requests per minute)
- API response time (p50, p95, p99)
- API error rate (errors per minute)
- API status code distribution

#### Agent Activity Dashboard

- Active agents count
- Agent connections per hour
- Agent disconnections per hour
- Agent heartbeat timeouts per hour
- Agent state distribution

#### Error Dashboard

- Error rate by type
- Top 10 error messages
- Error rate by agent
- Error rate by endpoint

#### Broadcast Health Dashboard

- Broadcast error rate
- Broadcast errors by model
- Time since last broadcast error

## Best Practices

### When to Add Logging

✅ **Do Log:**

- State transitions (agent, task, attack, campaign)
- API request start and completion
- Errors and exceptions
- Important business events (crack submission, task completion)
- Performance-critical operations

❌ **Don't Log:**

- Inside tight loops (performance impact)
- Sensitive data (passwords, tokens, plaintext)
- Excessive debug information in production
- Every database query (use tools like Bullet instead)

### Log Level Guidelines

- `info`: Normal operations, state transitions, API requests
- `warn`: Degraded performance, approaching thresholds, recoverable errors
- `error`: Errors that prevent operations, unhandled exceptions
- `debug`: Detailed diagnostic information (development only)

### Structured Logging Format

Always use the `[LogType]` prefix format:

```ruby
Rails.logger.info("[AgentLifecycle] connect: agent_id=#{agent.id} state_change=#{from}->#{to} timestamp=#{Time.current}")
```

Not:

```ruby
Rails.logger.info("Agent #{agent.id} connected")  # ❌ Unstructured, hard to parse
```

### Including Context

Always include relevant IDs and timestamps:

```ruby
Rails.logger.error("[APIError] VALIDATION_ERROR - Agent #{@agent.id} - Task #{@task.id} - Errors: #{@task.errors.full_messages.join(', ')} - #{Time.current}")
```

### Error Handling

Always rescue logging failures to prevent application crashes:

```ruby
def log_api_request_start
  # ... logging code ...
rescue StandardError => e
  Rails.logger.error("Failed to log API request start: #{e.message}")
end
```

### Testing Logging

Always test that important events are logged:

```ruby
it "logs agent shutdown" do
  agent = create(:agent, state: "active")
  expect(Rails.logger).to receive(:info).with(/\[AgentLifecycle\] shutdown:/)
  agent.shutdown
end
```

## Troubleshooting

### Logs Not Appearing

1. **Check Lograge is enabled:**

   ```ruby
   # In rails console
   Rails.application.config.lograge.enabled
   # Should return true
   ```

2. **Check log level:**

   ```ruby
   Rails.logger.level
   # Should return 1 (info) or lower
   ```

3. **Check log output location:**

   ```ruby
   Rails.logger.instance_variable_get(:@logdev).filename
   # Should show log file path
   ```

### Excessive Log Volume

1. **Reduce log level** in production:

   ```ruby
   config.log_level = :warn
   ```

2. **Add more ignored paths** to Lograge configuration

3. **Implement log sampling** for high-volume endpoints

### Logs Missing Context

1. **Verify custom_payload is configured** in Lograge initializer
2. **Check instance variables** are set before logging
3. **Add more context** to log messages

### Performance Impact

If logging impacts performance:

1. **Use log level filtering** (don't log debug in production)
2. **Move expensive operations** out of log statements
3. **Use background jobs** for complex logging
4. **Implement log sampling** for high-volume events

## Resources

- [Lograge Documentation](https://github.com/roidrage/lograge)
- [Rails Logging Guide](https://guides.rubyonrails.org/debugging_rails_applications.html#the-logger)
- [Structured Logging Best Practices](https://www.honeycomb.io/blog/structured-logging-and-your-team)
- [CipherSwarm AGENTS.md](../../AGENTS.md)
