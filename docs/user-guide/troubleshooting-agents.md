# Agent Troubleshooting Guide

This guide provides detailed troubleshooting steps for common agent issues, with a focus on task lifecycle errors and recovery procedures.

---

## Table of Contents

- [Task Not Found Errors](#task-not-found-errors)
- [Agent Recovery Procedures](#agent-recovery-procedures)
- [Server-Side Diagnostics](#server-side-diagnostics)
- [Campaign Quarantine from Agent Errors](#campaign-quarantine-from-agent-errors)
- [Best Practices](#best-practices)
- [Common Scenarios](#common-scenarios)
- [Network Connectivity Issues](#network-connectivity-issues)
- [Log Analysis](#log-analysis)

---

## Task Not Found Errors

### What Causes "Task Not Found" Errors?

Task not found errors (HTTP 404) occur when an agent attempts to interact with a task that no longer exists or is not assigned to that agent. Common causes include:

1. **Attack Abandonment**: The server abandoned the attack, destroying all associated tasks
2. **Task Reassignment**: The task was reassigned to another agent due to timeout or priority changes
3. **Task Completion**: The task was completed and removed from the system
4. **Server Maintenance**: Tasks were cleaned up during server maintenance operations

### Understanding Error Response Reason Codes

The server provides enhanced error responses with reason codes to help diagnose the cause:

#### `task_deleted`

**Meaning**: The task was destroyed on the server, likely due to attack abandonment.

**Example Response:**

```json
{
  "error": "Record not found",
  "reason": "task_deleted",
  "details": "Task was removed when attack was abandoned or completed"
}
```

**What to Do:**

- Stop all processing for this task immediately
- Don't retry the same task ID
- Request a new task via `GET /api/v1/client/tasks/new`
- Log the error with task ID and timestamp

**Root Causes:**

- Administrator manually abandoned the attack
- Attack exceeded its time limit
- Campaign priority changed, causing lower priority attacks to be abandoned
- All hashes in the hash list were cracked

#### `task_not_assigned`

**Meaning**: The task exists but is assigned to a different agent.

**Example Response:**

```json
{
  "error": "Record not found",
  "reason": "task_not_assigned",
  "details": "Task belongs to another agent"
}
```

**What to Do:**

- Stop processing this task immediately
- Request a new task via `GET /api/v1/client/tasks/new`
- Don't attempt to claim or access this task again
- Review agent configuration for conflicts

**Root Causes:**

- Task was never assigned to this agent
- Task was reassigned after the agent failed to accept it within the timeout period
- Multiple agents using the same credentials (configuration error)

#### `task_invalid`

**Meaning**: The task ID doesn't exist in the database.

**Example Response:**

```json
{
  "error": "Record not found",
  "reason": "task_invalid",
  "details": "Task ID does not exist"
}
```

**What to Do:**

- Verify the task ID in your logs
- Check for client-side bugs that might generate invalid task IDs
- Request a new task via `GET /api/v1/client/tasks/new`
- Report the issue if it persists

**Root Causes:**

- Client bug generating invalid task IDs
- Database migration or server reset
- Task was deleted long ago and ID no longer exists

#### No Reason Field (Legacy Response)

If the error response doesn't include a `reason` field, treat it as `task_deleted`:

```json
{
  "error": "Record not found"
}
```

**What to Do:**

- Follow the same recovery steps as `task_deleted`
- Update your client to support enhanced error responses

---

## Agent Recovery Procedures

This section details agent recovery mechanisms, including automatic retry logic, circuit breaker protection, and manual procedures when automatic recovery fails.

### Circuit Breaker Recovery

The agent includes a circuit breaker pattern to protect against cascading failures during server outages or network issues.

**How Circuit Breaker Works:**

1. **Closed State (Normal)**: All requests proceed normally. Failures are tracked.
2. **Open State (Protecting)**: After reaching the failure threshold (default: 5 failures), the circuit opens. API requests fail immediately with `ErrCircuitOpen` instead of attempting network calls.
3. **Half-Open State (Testing)**: After the timeout period (default: 60s), the circuit allows one probe request to test server recovery.
4. **Recovery**: If the probe succeeds, the circuit closes and normal operation resumes. If it fails, the circuit reopens for another timeout period.

**When Circuit Breaker Opens:**

Circuit breaker errors indicate server problems, not agent issues:

- Server is unavailable (restart, maintenance, crash)
- Network connectivity problems
- Repeated server errors (5xx responses)
- Sustained connection failures

**What You'll See:**

Agent logs during circuit open state:

```
[Warn] Circuit breaker open, server appears unresponsive
[Warn] Circuit breaker open, skipping task retrieval
```

Agent logs after recovery:

```
[Info] Applied server-recommended timeouts - connect=10s, read=30s, write=10s, request=60s
[Info] Agent authenticated successfully
```

**Recovery Actions:**

- **Agent will automatically recover**: No manual intervention needed
- **Error reporting is skipped**: Prevents cascading failures when server is down
- **No agent restart required**: Circuit breaker handles the failure and recovery
- **If circuit remains open persistently**: Investigate server availability and health

**Administrator Investigation:**

If the circuit breaker remains open for extended periods (>5 minutes):

1. Check server availability and health
2. Verify network connectivity between agent and server
3. Review server logs for errors or restart events
4. Check server resource usage (CPU, memory, database connections)
5. Verify firewall or network configuration hasn't changed

### Automatic Recovery from Task Loss

When your agent detects a task has been lost (404 error):

**Step 1: Implement Exponential Backoff**

```
Attempt 1: Immediate retry after 1 second
Attempt 2: Retry after 2 seconds (if still 404)
Attempt 3: Retry after 4 seconds (if still 404)
After 3 attempts: Abandon task reference
```

**Step 2: Request New Work**

After exhausting retry attempts:

```http
GET /api/v1/client/tasks/new
Authorization: Bearer <your_token>
```

**Step 3: Continue Normal Operations**

- If new task received: Accept and begin processing
- If no task available (204 response): Enter idle state and retry after configured interval
- Log the task loss event for audit purposes

### Task Acceptance Failures

Task acceptance can fail in two distinct ways, requiring different recovery procedures:

#### 404 Not Found During Acceptance (`ErrTaskAcceptNotFound`)

**What It Means:**

The task disappeared between assignment and acceptance—a normal race condition when multiple agents compete for work.

**Agent Behavior:**

- **No AbandonTask call**: The task no longer exists on the server, so abandonment is unnecessary
- **No retry delay**: Immediate cleanup and move to next task
- **Clean up local files**: Remove any downloaded resources for the vanished task
- **Log at Info severity**: "Task no longer exists on server"
- **Request new work immediately**: `GET /api/v1/client/tasks/new`

**Example Flow:**

```
1. Agent receives task assignment (Task ID 123)
2. Another agent accepts Task 123 first
3. Agent attempts to accept Task 123 → 404 Not Found
4. Agent cleans up local files
5. Agent immediately requests new task (no delay)
```

**When This Occurs:**

- Multiple agents requesting tasks simultaneously
- High agent-to-task ratio (more agents than available tasks)
- Task was reassigned due to another agent's timeout

**Normal or Concerning?**

This is **normal behavior** in multi-agent deployments. The task was claimed by a faster agent. Monitor the frequency—occasional 404s are expected, but if >10% of acceptance attempts fail, investigate task assignment logic or reduce the number of idle agents.

#### Non-404 Acceptance Failure (`ErrTaskAcceptFailed`)

**What It Means:**

The server rejected the acceptance for reasons other than task unavailability (e.g., validation error, server error, permission issue).

**Agent Behavior:**

- **Call AbandonTask**: Notify server to release the task for reassignment
- **Clean up local files**: Remove any downloaded resources
- **Sleep on failure**: Wait configured delay (e.g., 10 seconds) before requesting new work
- **Log at Critical severity**: "Error accepting task" with full error details

**Example Flow:**

```
1. Agent receives task assignment (Task ID 456)
2. Agent attempts to accept Task 456 → 500 Internal Server Error
3. Agent calls AbandonTask to release Task 456
4. Agent cleans up local files
5. Agent sleeps for configured delay
6. Agent requests new task
```

**When This Occurs:**

- Server experiencing internal errors
- Agent authentication/authorization issues
- Invalid attack parameters
- Database connectivity problems

**Normal or Concerning?**

This is **concerning behavior** that requires investigation. Non-404 acceptance failures indicate a systemic issue with the server, agent configuration, or attack parameters. These should be rare (\<1%) and investigated immediately.

### When to Restart an Agent

**Restart Required:**

- Agent enters an unrecoverable error state
- Memory leaks detected (monitor memory usage)
- Configuration changes applied
- Agent reports persistent authentication failures
- Multiple consecutive task losses (>10 in 1 hour)

**Restart NOT Required:**

- Single task loss (404 error) - automatic recovery should handle this
- Temporary network issues - agent automatically retries with exponential backoff
- Server returns 5xx errors occasionally - automatic retry logic handles this
- Status update returns 202 (stale) or 410 (paused) - these are normal operations
- Circuit breaker opens - agent will automatically recover when server becomes available

### Manual Recovery Procedures

**If Automatic Recovery Fails:**

1. **Stop the Agent**:

   ```bash
   # Stop agent service
   systemctl stop cipherswarm-agent
   # or use your agent's stop command
   ```

2. **Clear Local State** (if applicable):

   ```bash
   # Remove any local task cache
   rm -rf /var/lib/cipherswarm/task_cache/*

   # Clear any stuck processes
   pkill -f hashcat
   ```

3. **Verify Server Connectivity**:

   ```bash
   # Test health endpoint (unauthenticated)
   curl -v http://server.example.com/api/v1/client/health

   # Test authentication
   curl -H "Authorization: Bearer <token>" \
     https://server.example.com/api/v1/client/authenticate
   ```

4. **Restart the Agent**:

   ```bash
   systemctl start cipherswarm-agent
   ```

5. **Monitor Logs**:

   ```bash
   journalctl -u cipherswarm-agent -f
   ```

---

## Server-Side Diagnostics

### Checking Server Logs for Task Lifecycle Events

Server logs include structured events for task lifecycle management:

**Log File Locations:**

- **Development**: `log/development.log`
- **Production**: `/var/log/cipherswarm/production.log` (or configured location)
- **Docker**: `docker logs cipherswarm-web`

### Log Message Patterns

#### Attack Abandonment

```
[Attack 123] Abandoning attack for campaign 45, destroying 5 tasks: [678, 679, 680, 681, 682]
[Attack 123] Tasks with agent assignments: Task 678 (Agent 10), Task 679 (Agent 10), Task 680 (Agent 11), Task 681 (Agent 12), Task 682 (Agent 12)
[Attack 123] Tasks destroyed: [678, 679, 680, 681, 682]
[Attack 123] Attack abandoned, campaign 45 updated at 2026-01-06 15:30:45 UTC
```

**What This Tells You:**

- Attack ID 123 was abandoned
- 5 tasks were destroyed
- Tasks were assigned to agents 10, 11, and 12
- Those agents will receive 404 errors on their next status update

#### Task State Transitions

```
[Task 678] Agent 10 - Attack 123 - State change: running -> abandoned - Triggering attack abandonment
[Task 679] Agent 10 - Attack 123 - State change: pending -> running - Task accepted and running
[Task 680] Agent 11 - Attack 123 - State change: running -> completed - Uncracked hashes: 1250
[Task 681] Agent 12 - Attack 123 - State change: running -> exhausted - Keyspace exhausted
```

**What This Tells You:**

- Task state changes are logged with agent ID and attack ID
- You can trace the lifecycle of specific tasks
- Completed tasks show remaining uncracked hash count

#### Task Not Found Errors

```
[TaskNotFound] Task 678 - Agent 10 - Reason: task_deleted - Task was removed when attack was abandoned or completed - 2026-01-06 15:30:46 UTC
[TaskNotFound] Task 999 - Agent 15 - Reason: task_invalid - Task ID does not exist - 2026-01-06 15:31:00 UTC
[TaskNotFound] Task 700 - Requested by Agent 10 - Assigned to Agent 11 - Reason: task_not_assigned - 2026-01-06 15:31:15 UTC
```

**What This Tells You:**

- Which agent encountered the error
- What task ID caused the error
- The specific reason for the 404 error
- Timestamp for correlation with agent logs

### Identifying Frequent Task Abandonment

To check if attacks are being abandoned frequently:

```bash
# Count attack abandonment events in last hour
grep "\[Attack.*Abandoning attack" /var/log/cipherswarm/production.log | \
  grep "$(date -u +%Y-%m-%d\ %H)" | \
  wc -l

# Show most recent abandonments with task counts
grep "\[Attack.*Abandoning attack" /var/log/cipherswarm/production.log | \
  tail -10
```

**Normal Behavior:**

- Occasional abandonments due to campaign priority changes
- Abandonments when all hashes are cracked
- Abandonments during manual intervention

**Concerning Patterns:**

- High frequency abandonments (>10 per hour)
- Same attack being abandoned repeatedly
- Abandonments affecting multiple agents simultaneously
- No clear trigger (check for system issues)

### Task Assignment Skip Reasons

When agents request work but receive no tasks, the task assignment service logs detailed reasons to help operators diagnose agent idleness. These `[TaskAssignment]` log entries make it easier to understand why agents remain idle.

**Log Pattern:**

When no task is assigned, you'll see an info-level log entry like:

```
[TaskAssignment] no_task_assigned: agent_id=123 reasons=no_available_attacks, all_hashes_cracked allowed_hash_type_ids=[...] project_ids=[...] timestamp=...
```

**Skip Reasons:**

- `no_available_attacks` - No attacks are available for the agent's hash types and projects
- `all_hashes_cracked` - All hashes in available attacks have been cracked
- `pending_tasks_not_owned` - Pending tasks exist but are assigned to other agents
- `performance_threshold_not_met` - Agent doesn't meet performance requirements for available attacks
- `grace_period_active` - Paused tasks exist but are still in the grace period (waiting for original agent)

**Additional Debug Logs:**

For more granular diagnostics, enable debug-level logging to see per-attack skip reasons:

- `[TaskAssignment] no_uncracked_hashes: agent_id=X attack_id=Y` - Specific attack has no remaining work
- `[TaskAssignment] pending_tasks_taken: agent_id=X attack_id=Y` - Another agent owns pending tasks for this attack
- `[TaskAssignment] grace_period_active: agent_id=X grace_cutoff=... blocked_task_count=N` - Tasks are blocked by grace period
- `[TaskAssignment] performance_threshold_not_met: agent_id=X attack_id=Y hash_mode=Z` - Agent's benchmark too slow for this attack

**Troubleshooting with Skip Reasons:**

1. **no_available_attacks**: Check that campaigns are active and match the agent's configured hash types and project assignments. Verify campaigns are not quarantined.
2. **all_hashes_cracked**: All work is complete; consider starting new campaigns or adjusting hash lists
3. **pending_tasks_not_owned**: Other agents have claimed available work; this is normal in multi-agent environments
4. **performance_threshold_not_met**: Review agent benchmark results and attack complexity requirements
5. **grace_period_active**: Tasks are temporarily reserved for their original agents; wait for grace period expiration or agent reconnection

### Correlating Agent Logs with Server Logs

**Process:**

1. **Extract Task ID from Agent Log**:

   ```
   Agent log: "Error submitting status for task 678: 404 Not Found"
   Task ID: 678
   ```

2. **Search Server Logs for Task ID**:

   ```bash
   grep "Task 678" /var/log/cipherswarm/production.log
   ```

3. **Look for Attack Events**:

   ```bash
   # Find attack ID from task logs
   grep "Task 678.*Attack" /var/log/cipherswarm/production.log

   # Then search for attack events
   grep "Attack 123" /var/log/cipherswarm/production.log
   ```

4. **Timeline Reconstruction**:

   - When was task created?
   - When was task accepted by agent?
   - When did state changes occur?
   - When was attack abandoned?
   - When did agent receive 404?

5. **Identify Root Cause**:

   - Attack abandonment due to priority change
   - Task reassignment due to timeout
   - System maintenance or restart
   - Bug or unexpected behavior

---

## Campaign Quarantine from Agent Errors

CipherSwarm automatically quarantines campaigns when agents submit errors indicating unrecoverable configuration or hash format issues. This prevents agents from repeatedly attempting tasks that will always fail due to misconfigured attacks or incompatible hash lists.

### What Triggers Campaign Quarantine?

The server quarantines a campaign when an agent submits an error with structured metadata meeting these conditions:

- `metadata.other.retryable == false` (error is not transient), AND
- `metadata.other.category == "hash_format"` (hash format error), OR
- `metadata.other.terminal == true` (terminal hashcat failure)

**Common Error Types That Trigger Quarantine:**

| Error Type                 | Example Message                   | Reason                                                 |
| -------------------------- | --------------------------------- | ------------------------------------------------------ |
| **Token Length Exception** | Token length exception            | Hash list format doesn't match hash type specification |
| **Separator Unmatched**    | Separator unmatched               | Hash delimiter incorrect for hash type                 |
| **Hash Encoding Error**    | Hash encoding exception           | Hash list encoding invalid or corrupted                |
| **No Hashes Loaded**       | No hashes loaded                  | Hash list is empty or unreadable                       |
| **Invalid Attack Mode**    | Invalid attack mode for hash type | Attack configuration incompatible with hash type       |
| **Terminal Hashcat Error** | Device memory allocation failed   | Unrecoverable hardware or configuration error          |

### Identifying Quarantined Campaigns

**Web Interface Indicators:**

1. **Campaigns Index:**

   - Red "Quarantined" badge appears on quarantined campaign cards
   - Use the "Quarantined" filter button to view all quarantined campaigns

2. **Campaign Show Page:**

   - Red alert banner displays at the top with "Campaign Quarantined" message
   - Shows the quarantine reason (original error message from agent)
   - Admin users see a "Clear Quarantine" button

**Checking Quarantine Status via Rails Console:**

```ruby
# Find all quarantined campaigns
Campaign.quarantined

# Check if specific campaign is quarantined
campaign = Campaign.find(123)
campaign.quarantined?  # => true or false
campaign.quarantine_reason  # => error message
```

### How Quarantine Affects Task Assignment

**Task Assignment Behavior:**

- `TaskAssignmentService` excludes quarantined campaigns from all task queries
- Agents will NOT receive new tasks from quarantined campaigns
- Prevents agents from wasting compute resources on tasks that will always fail
- Existing tasks already running on agents are NOT affected (they continue to completion or error)

**Task Assignment Queries Affected:**

The following task assignment paths exclude quarantined campaigns:

1. `find_existing_incomplete_task` - resuming agent's own incomplete tasks
2. `find_own_paused_task` - resuming agent's own paused tasks
3. `find_unassigned_paused_task` - claiming unassigned paused tasks during grace period
4. `available_attacks` - creating new tasks from available attacks

### Resolving Quarantine

#### Automatic Quarantine Clearing

Quarantine automatically clears when you update the underlying configuration that caused the error:

**Hash List Changes (clears quarantine on all associated campaigns):**

- Change hash type: `hash_list.update!(hash_type: new_hash_type)`
- Replace hash list file: `hash_list.file.attach(new_file)`

**Attack Parameter Changes (clears quarantine on parent campaign):**

- Attack mode change
- Word list, rule list, or mask list reassignment
- Mask changes
- Custom charset modifications
- Markov settings changes
- Any hashcat configuration parameter update

**Why Automatic Clearing?**

The server assumes that configuration changes indicate the administrator has corrected the underlying issue. This allows campaigns to be retried without manual intervention.

#### Manual Quarantine Clearing (Admin Only)

**Via Web Interface:**

1. Navigate to the quarantined campaign's show page
2. Click the "Clear Quarantine" button in the red alert banner
3. Confirm the action
4. The campaign becomes eligible for task assignment again

**Via Rails Console:**

```ruby
campaign = Campaign.find(123)
campaign.clear_quarantine!
# => Sets quarantined=false, clears quarantine_reason
```

**Before Clearing Quarantine:**

- Review the quarantine reason (error message)
- Verify the underlying issue has been fixed
- Check agent error logs for details
- Ensure hash list and attack parameters are correct
- Test with a small hash list if unsure

**After Clearing Quarantine:**

If you clear quarantine without fixing the underlying issue:

- Agents will receive tasks from the campaign again
- The campaign will likely be re-quarantined immediately when the same error occurs
- Agent resources will be wasted on doomed tasks

### Quarantine vs Agent Errors

**Not All Errors Trigger Quarantine:**

- **Retryable Errors:** Network failures, temporary GPU errors, and transient issues do NOT quarantine campaigns
- **Transient Failures:** Agent crashes, connection losses, and timeout errors are NOT terminal
- **Recoverable Errors:** Errors with `retryable: true` metadata never trigger quarantine

**Error Visibility:**

- All agent errors are visible in the campaign/attack error logs regardless of quarantine status
- Quarantine only affects task assignment, not error reporting
- You can view error details even for quarantined campaigns

**Quarantine Lifecycle Log Events:**

The server logs quarantine events for audit and troubleshooting:

```
[AgentLifecycle] campaign_quarantined: campaign_id=123 agent_id=45 task_id=678 reason="Token length exception" timestamp=2026-03-16 10:30:00 UTC
```

If quarantine triggering fails (rare):

```
[AgentLifecycle] quarantine_failed: campaign_id=123 agent_id=45 task_id=678 error=ActiveRecord::RecordInvalid - Validation failed timestamp=2026-03-16 10:30:00 UTC
```

### Troubleshooting Quarantined Campaigns

**Scenario: Campaign Quarantined Immediately After Creation**

**Symptoms:**

- New campaign quarantined after first agent attempts task
- Agents not receiving tasks from campaign
- Error logs show hash format errors

**Diagnosis:**

1. Check hash list format matches selected hash type
2. Verify hash list file is not empty
3. Ensure attack mode is compatible with hash type
4. Review agent error message for specific issue

**Resolution:**

1. Download a sample of the hash list
2. Verify hashes match the expected format for the hash type
3. Fix hash list formatting or change hash type
4. Upload corrected hash list (quarantine clears automatically)

**Scenario: Campaign Quarantined After Hash Type Change**

**Symptoms:**

- Campaign was working, then quarantined after hash type change
- Agent errors mention token length or separator issues

**Cause:**

- Hash list format is incompatible with new hash type
- Hash type was changed without updating hash list

**Resolution:**

1. Revert hash type to original value (clears quarantine)
2. OR reformat hash list for new hash type and re-upload

**Scenario: Checking if Agents Are Skipping Quarantined Campaigns**

Use task assignment skip logs to see if quarantine is blocking work:

```bash
# Check for quarantine-related task assignment skips
grep "no_available_attacks" /var/log/cipherswarm/production.log | grep "agent_id=123"
```

If agents are idle and campaigns are quarantined, they won't appear in skip logs (quarantined campaigns are excluded from queries before skip reason logging).

---

## Best Practices

### Agent Configuration

**Recommended Settings:**

```yaml
agent:
  heartbeat_interval: 60 # seconds
  status_update_interval: 15 # seconds during active work
  task_timeout: 86400 # 24 hours
  max_404_retries: 3
  retry_backoff_multiplier: 2
  max_retry_backoff: 60 # seconds
  request_new_task_interval: 300 # 5 minutes when idle
  # HTTP resilience settings (can be overridden by server-recommended values)
  connect_timeout: 10 # seconds - TCP connect timeout
  read_timeout: 30 # seconds - API response read timeout
  write_timeout: 10 # seconds - API request write timeout
  request_timeout: 60 # seconds - overall request timeout
  api_max_retries: 3 # total attempts (1 = no retry)
  api_retry_initial_delay: 1 # seconds - first retry delay
  api_retry_max_delay: 30 # seconds - cap for exponential backoff
  circuit_breaker_failure_threshold: 5 # failures before circuit opens
  circuit_breaker_timeout: 60 # seconds - duration before half-open retry
```

**Why These Settings:**

- **heartbeat_interval**: Keeps server aware of agent status without overwhelming it
- **status_update_interval**: Provides timely progress updates
- **task_timeout**: Allows long-running tasks while preventing indefinite hangs
- **max_404_retries**: Balances recovery attempts with quick failure detection
- **retry_backoff**: Prevents overwhelming server during issues
- **request_new_task_interval**: Regular check for work without excessive polling
- **connect_timeout**: Prevents indefinite hangs on connection establishment
- **read_timeout**: Prevents indefinite hangs waiting for server response
- **write_timeout**: Prevents indefinite hangs sending request payload
- **request_timeout**: Enforces overall limit on API call duration
- **api_max_retries**: Automatically retries network errors and 5xx responses with exponential backoff
- **api_retry_initial_delay**: Starting delay for retry backoff (doubles each attempt)
- **api_retry_max_delay**: Caps retry delays to prevent excessive waiting
- **circuit_breaker_failure_threshold**: Opens circuit to prevent cascading failures after repeated errors
- **circuit_breaker_timeout**: Duration before attempting recovery after circuit opens

**Server-Recommended Settings:**

The agent fetches recommended timeout, retry, and circuit breaker settings from the server's `/configuration` endpoint. If present, these server values override the local configuration to ensure optimal performance for the specific server deployment. The agent logs when server-recommended settings are applied.

**Server-Provided Resilience Parameters:**

Agents fetch timeout and retry configuration from the server via the `/api/v1/client/configuration` endpoint. The configuration response includes:

- **Timeout settings**: `connect_timeout`, `read_timeout`, `write_timeout`, `request_timeout`
- **Retry settings**: `max_attempts`, `initial_delay`, `max_delay`
- **Circuit breaker settings**: `failure_threshold`, `timeout`

These parameters allow server operators to tune agent behavior without redeploying agent software. Agents should apply these values when first connecting and refresh them periodically (e.g., every 24 hours) by re-fetching the configuration endpoint. See the [Client Resilience Recommendations](../api-reference-agent-auth.md#client-resilience-recommendations) section of the API reference for implementation details.

### Monitoring Agent Health

**Metrics to Track:**

1. **Task Success Rate**: `(completed_tasks / total_assigned_tasks) * 100`

   - Target: >95%
   - Alert: \<90%

2. **Acceptance Failure Rate**: `(non_404_accept_failures / total_accept_attempts) * 100`

   - Target: \<1%
   - Alert: >2%
   - Note: Excludes 404 errors, which are normal race conditions

3. **Acceptance 404 Rate**: `(404_accept_failures / total_accept_attempts) * 100`

   - Target: \<5%
   - Warning: 5-10% (too many idle agents)
   - Alert: >10% (task assignment issues)

4. **Average Task Duration**: Time from accept to completion

   - Track for anomalies
   - Alert on sudden increases

5. **Network Latency**: Round-trip time for API requests

   - Target: \<500ms
   - Alert: >2000ms

6. **Memory Usage**: Agent memory consumption

   - Target: Stable over time
   - Alert on continuous growth (potential leak)

### Alert Configuration

**Critical Alerts:**

- Agent offline for >10 minutes
- Non-404 acceptance errors at any frequency (indicates server/config issues)
- Authentication failures
- No tasks completed in last hour (when tasks available)

**Warning Alerts:**

- 404 acceptance error rate >10% in 15-minute window
- Task success rate \<95%
- High memory usage (>80% of limit)
- Network latency >1000ms

**Info-Level Events (No Alert):**

- Individual 404 errors during task acceptance (expected race condition)
- Occasional task status 404s (task completed elsewhere)
- Campaign pause/resume notifications

### Regular Health Checks

**Agent Self-Checks** (run every 5 minutes):

1. Verify server connectivity
2. Check authentication token validity
3. Monitor local resource usage (CPU, memory, disk)
4. Verify hashcat binary availability
5. Check for hung processes

**Administrator Checks** (run daily):

1. Review agent error logs
2. Check 404 error rates across all agents
3. Verify no stuck tasks (>24 hours)
4. Monitor attack abandonment frequency
5. Review agent uptime statistics

---

## Task Management Actions

CipherSwarm V2 provides task management actions directly from the web interface, giving administrators control over individual tasks without requiring command-line access.

### Task Detail View

To view task details:

1. Navigate to a campaign and expand an attack
2. Click on a task row to open the task detail page
3. The detail page shows:
   - Task state and progress
   - Assigned agent
   - Start time and duration
   - Hash rate and keyspace progress
   - Error messages (if any)
   - Status history timeline

### Cancel Task Action

To cancel a running task:

1. Open the task detail page
2. Click **Cancel**
3. Confirm the cancellation
4. The task is stopped and its state changes to cancelled
5. The unprocessed keyspace becomes available for reassignment

**When to cancel**:

- Agent is performing poorly on this task
- Task is no longer needed (e.g., all hashes cracked by another task)
- Agent needs to be taken offline for maintenance

### Retry Task Action

To retry a failed task:

1. Open the task detail page for a failed task
2. Click **Retry**
3. The task state resets to pending
4. The retry count increments for tracking purposes
5. An available agent picks up the retried task

**When to retry**:

- Task failed due to a transient error (network issue, temporary GPU error)
- The underlying issue has been resolved
- The task has not exceeded the maximum retry count

### Reassign Task Action

To reassign a task to a different agent:

1. Open the task detail page
2. Click **Reassign**
3. The task is released from the current agent
4. The task returns to pending state
5. An available agent picks up the task automatically

**When to reassign**:

- Current agent is performing poorly
- Agent needs to be taken offline
- Load balancing across agents
- Agent is stuck but not formally failed

### Task Status History

Each task maintains a complete status history:

| Timestamp           | State     | Details                       |
| ------------------- | --------- | ----------------------------- |
| 2026-01-15 10:00:00 | Pending   | Task created                  |
| 2026-01-15 10:00:05 | Running   | Assigned to Agent GPU-Node-01 |
| 2026-01-15 10:30:00 | Paused    | Campaign paused by user       |
| 2026-01-15 11:00:00 | Running   | Campaign resumed              |
| 2026-01-15 12:00:00 | Completed | 100% keyspace processed       |

This history is visible on the task detail page and helps with debugging task lifecycle issues.

### Task Error Handling

When a task fails, the error information includes:

- **Error Message**: The specific error from hashcat or the agent
- **Error Time**: When the error occurred
- **Agent Details**: Which agent encountered the error
- **Retry Count**: How many times the task has been retried

Common task errors and their solutions:

| Error                          | Cause                          | Solution                               |
| ------------------------------ | ------------------------------ | -------------------------------------- |
| GPU memory allocation failed   | Insufficient GPU memory        | Reassign to agent with more GPU memory |
| Hashcat returned error code -1 | Invalid attack parameters      | Review attack configuration            |
| Resource download timeout      | Network or MinIO issue         | Check MinIO status, retry task         |
| Agent connection lost          | Agent went offline during task | Wait for agent recovery, reassign      |
| Temperature abort              | GPU overheated                 | Check agent cooling, reduce workload   |

---

## Common Scenarios

### Scenario 1: Attack Abandoned While Agent Processing

**Symptoms:**

- Agent actively processing task
- Agent receives 404 on next `submit_status` call
- Error response includes `reason: "task_deleted"`

**Cause:**

Server abandoned the attack, destroying all associated tasks. Common reasons:

- Campaign priority changed (higher priority campaign activated)
- Administrator manually abandoned attack
- All hashes were cracked by other agents
- Attack time limit exceeded

**Server Logs Show:**

```
[Attack 123] Abandoning attack for campaign 45, destroying 5 tasks: [678, 679, 680, 681, 682]
[Attack 123] Tasks destroyed: [678, 679, 680, 681, 682]
```

**Resolution:**

1. Agent stops processing immediately upon 404
2. Agent implements exponential backoff (1s, 2s, 4s)
3. After 3 attempts, agent abandons task reference
4. Agent requests new task via `GET /api/v1/client/tasks/new`
5. Agent continues with new work

**Prevention:**

- Monitor campaign priorities
- Set appropriate task timeouts
- Implement graceful handling of stale task detection
- Check task status before expensive operations

### Scenario 2: Network Interruption Causing Stale References

**Symptoms:**

- Network connectivity lost for period of time
- After network recovery, all task operations return 404
- Multiple tasks affected simultaneously

**Cause:**

During network outage:

- Tasks expired and were reassigned
- Server considered agent offline
- Tasks claimed by other agents

**Server Logs Show:**

```
[Agent 10] Last seen: 2026-01-06 14:00:00 (60 minutes ago)
[Task 678] Reassigned from Agent 10 to Agent 15 due to timeout
[TaskNotFound] Task 678 - Requested by Agent 10 - Assigned to Agent 15 - Reason: task_not_assigned
```

**Agent Behavior with HTTP Resilience:**

The agent automatically handles network interruptions through retry and circuit breaker mechanisms:

1. **Retry Logic**: Network errors and 5xx responses are automatically retried (up to 3 attempts by default) with exponential backoff
2. **Circuit Breaker Protection**: After repeated failures (5 by default), the circuit breaker opens to prevent cascading failures
3. **Automatic Recovery**: When the circuit breaker opens, agents log "circuit open" messages and skip server requests that would fail
4. **Half-Open Probe**: After the timeout period (60s by default), the circuit breaker allows a single probe request to test server recovery
5. **Circuit Closes**: Once the server responds successfully, the circuit closes and normal operation resumes

**Resolution:**

1. Agent detects network outage through failed requests
2. Retry transport attempts up to 3 times with exponential backoff (1s, 2s, 4s)
3. After exhausting retries, circuit breaker opens if failure threshold reached
4. Agent logs "circuit open" messages instead of repeated errors
5. After circuit breaker timeout (60s), agent attempts probe request
6. If server is available, circuit closes and agent re-authenticates
7. Agent abandons all local task references (now stale)
8. Agent requests new tasks
9. Agent resumes normal operations

**What You'll See in Logs:**

During the outage:

```
[Warn] Heartbeat failed, backing off - failures=3, next_retry=8s
[Warn] Circuit breaker open, server appears unresponsive - failures=5
[Warn] Circuit breaker open, skipping task retrieval
```

After recovery:

```
[Info] Applied server-recommended timeouts - connect=10s, read=30s, write=10s, request=60s
[Info] Agent authenticated successfully
[Debug] Requesting new task
```

**Prevention:**

- Implement network connectivity monitoring
- Detect outages early and enter offline mode
- Don't accumulate stale task references
- Re-authenticate after network issues
- Circuit breaker and retry logic handle transient failures automatically
- Monitor circuit breaker open events for persistent connectivity issues

### Scenario 3: Task Not Found During Acceptance

**Symptoms:**

- Agent requests new task
- Agent receives task assignment
- Agent attempts to accept task
- Server returns 404 (task vanished)

**Cause:**

This is an **expected race condition** when multiple agents compete for tasks:

- Multiple agents requested tasks simultaneously
- Server assigned same task to multiple agents
- One agent accepted faster, others receive 404
- Task was reassigned before acceptance completed

**Agent Logs Show:**

```
[Info] Agent 11 - Failed to accept task 700: task not found during acceptance
[Info] Task no longer exists on server
[Debug] Cleaned up local files for task 700
[Debug] Requesting new task
```

**Server Logs Show:**

```
[Task 700] Agent 10 - Attack 123 - State change: pending -> running - Task accepted and running
[TaskNotFound] Task 700 - Requested by Agent 11 - Assigned to Agent 10 - Reason: task_not_assigned
```

**Resolution (Automatic):**

1. Agent receives 404 on `accept_task`
2. Agent recognizes `ErrTaskAcceptNotFound` sentinel error
3. Agent **skips** AbandonTask call (task already gone)
4. Agent cleans up local files immediately
5. Agent requests new task **without delay**
6. Agent continues normally with new task

**Why No AbandonTask Call?**

The task no longer exists on the server (another agent claimed it), so calling AbandonTask would generate unnecessary API traffic and potential error noise. The agent simply cleans up locally and moves on.

**Monitoring:**

- **Normal**: Occasional 404s during acceptance (\<5% of attempts)
- **Warning**: Frequent 404s (5-10% of attempts) may indicate too many idle agents
- **Critical**: Very high 404 rate (>10% of attempts) suggests task assignment issues

**Prevention:**

- Accept tasks promptly after receiving them (within 10 seconds)
- Don't delay between receiving and accepting
- Balance agent count with available work
- Monitor acceptance failure rates across the agent pool

### Scenario 4: Server Restart Causing Task Reassignment

**Symptoms:**

- All agents report 404 errors after specific time
- Errors occur across all agents simultaneously
- Tasks were working normally before

**Cause:**

- Server was restarted for maintenance or crash recovery
- In-memory task assignments lost
- Database state reset or rolled back
- Tasks reassigned or removed during restart

**Server Logs Show:**

```
[System] CipherSwarm server starting up
[System] Loading campaigns and attacks from database
[System] 15 tasks in running state reset to pending
```

**Agent Behavior During Server Restart:**

When the server becomes unavailable during a restart:

1. **Retry Logic Activates**: Network errors and connection failures are automatically retried (up to 3 attempts by default) with exponential backoff
2. **Circuit Breaker Opens**: After repeated failures (5 by default), the circuit breaker opens to protect against cascading failures
3. **Error Reporting Skipped**: When the circuit breaker is open, agents skip error reporting to the server (which would fail anyway)
4. **Automatic Recovery**: The circuit breaker automatically attempts recovery after the configured timeout (60s by default)
5. **Half-Open Probe**: A single probe request tests if the server has recovered
6. **Circuit Closes**: Once the server responds successfully, the circuit closes and agents resume normal operation

**Resolution:**

01. Agent detects server unavailability through failed API requests
02. Retry transport attempts each request up to 3 times with exponential backoff
03. After exhausting retries, circuit breaker opens if failure threshold reached
04. Agent logs "circuit open" messages instead of attempting failed requests
05. After circuit breaker timeout (60s), agent sends probe request
06. When server is back online, circuit breaker closes
07. Agent re-authenticates with server
08. Agent abandons all current task references (now stale)
09. Agent requests new tasks
10. Agent resumes normal operations

**What You'll See in Logs:**

During server downtime:

```
[Warn] Heartbeat failed, backing off - failures=3, next_retry=8s
[Warn] Circuit breaker open, server appears unresponsive - failures=5
[Warn] Circuit breaker open, skipping task retrieval
```

After server recovery:

```
[Info] Applied server-recommended timeouts - connect=10s, read=30s, write=10s, request=60s
[Info] Agent authenticated successfully
[Debug] Requesting new task
```

**Key Points:**

- **No agent restart needed**: The circuit breaker and retry logic handle server restarts automatically
- **Circuit breaker protects agents**: Prevents log flooding and resource exhaustion during server downtime
- **Automatic recovery**: Agents detect server availability and resume work without manual intervention
- **Error reporting is smart**: Skipped when circuit is open to avoid cascading failures

**Prevention:**

- Monitor server uptime and health
- Implement graceful server restart procedures
- Notify agents of planned maintenance (though circuit breaker handles unplanned outages)
- Persist task assignments to database
- Circuit breaker and retry logic automatically handle server restarts
- Monitor circuit breaker open events to detect server availability issues

---

## Network Connectivity Issues

### Scenario: Agent Hangs or Becomes Unresponsive

**Symptoms:**

- Agent appears to hang indefinitely with no progress
- No error messages in agent logs
- Agent does not respond to signals or commands
- System resources (CPU, memory) appear normal but agent is frozen
- Network connectivity exists but requests never complete

**Cause:**

The server is unresponsive or extremely slow, and the agent is waiting for HTTP responses without enforcing timeouts. Before resilience improvements, agents could wait indefinitely for server responses, causing them to appear hung.

**Solution:**

Agents that support server-provided resilience configuration (introduced in CipherSwarm V2) automatically configure timeouts and retry logic. Ensure your agent:

1. **Fetches Resilience Parameters**: The agent must call `GET /api/v1/client/configuration` on startup and periodically (e.g., every 24 hours) to receive timeout and retry settings.

2. **Applies Timeout Configuration**: The agent HTTP client should honor these timeout values:

   - `connect_timeout`: Maximum time to establish TCP connection
   - `read_timeout`: Maximum time to wait for response data
   - `write_timeout`: Maximum time to send request data
   - `request_timeout`: Overall deadline for entire request

3. **Implements Retry Logic**: The agent should implement exponential backoff with jitter using the `recommended_retry` parameters from the configuration endpoint.

4. **Uses Circuit Breaker Pattern**: After repeated failures (default: 5 consecutive failures), the agent should "open" the circuit and short-circuit requests for a timeout period (default: 30 seconds), periodically probing the health endpoint to determine when to retry.

**Diagnostic Steps:**

1. **Check if agent supports resilience features**:

   ```bash
   # Check agent version and features
   cipherswarm-agent --version
   cipherswarm-agent --features
   ```

2. **Test server health endpoint**:

   ```bash
   # This endpoint does not require authentication
   curl -v http://your-server/api/v1/client/health
   ```

   **Expected response (healthy server)**:

   ```json
   {
     "status": "ok",
     "api_version": 1,
     "timestamp": "2026-03-12T10:30:00Z",
     "database": "healthy"
   }
   ```

   **Expected response (degraded server)**:

   ```json
   {
     "status": "degraded",
     "api_version": 1,
     "timestamp": "2026-03-12T10:30:00Z",
     "database": "unhealthy"
   }
   ```

3. **Verify resilience configuration is being fetched**:

   ```bash
   # Check that configuration endpoint returns timeout settings
   curl -H "Authorization: Bearer <token>" \
     http://your-server/api/v1/client/configuration | \
     jq '.recommended_timeouts, .recommended_retry, .recommended_circuit_breaker'
   ```

4. **Monitor agent logs for timeout and retry behavior**:

   Look for log entries indicating:

   - Connection timeout errors
   - Request timeout errors
   - Retry attempts with exponential backoff
   - Circuit breaker state transitions (closed → open → half-open)

**Recovery Steps:**

If the agent is already hung:

1. **Stop the hung agent process**:

   ```bash
   # Forcefully terminate if graceful shutdown fails
   systemctl stop cipherswarm-agent
   # or
   pkill -9 cipherswarm-agent
   ```

2. **Verify server health** before restarting:

   ```bash
   curl http://your-server/api/v1/client/health
   ```

3. **Restart the agent** only if server is healthy:

   ```bash
   systemctl start cipherswarm-agent
   ```

4. **Monitor agent logs** to confirm proper timeout handling:

   ```bash
   journalctl -u cipherswarm-agent -f
   ```

**Prevention:**

- **Update agents**: Ensure all agents are running versions that support server-provided resilience configuration
- **Monitor health endpoint**: Set up monitoring on `GET /api/v1/client/health` to detect server degradation before agents hang
- **Configure alerting**: Alert when the health endpoint returns `status: "degraded"` or times out
- **Test resilience settings**: Periodically test agent behavior under server degradation (slow responses, timeouts) to verify resilience features are working
- **Review server configuration**: If agents frequently experience timeouts, review the resilience parameters provided by `GET /api/v1/client/configuration` and adjust them on the server side if needed

**Server-Side Configuration:**

Server operators can tune resilience parameters without redeploying agents by modifying the application configuration:

```yaml
# config/application.yml (example)
recommended_connect_timeout: 10      # seconds
recommended_read_timeout: 30         # seconds
recommended_write_timeout: 30        # seconds
recommended_request_timeout: 60      # seconds
recommended_retry_max_attempts: 10
recommended_retry_initial_delay: 1   # seconds
recommended_retry_max_delay: 300     # seconds (5 minutes)
recommended_circuit_breaker_failure_threshold: 5
recommended_circuit_breaker_timeout: 30  # seconds
```

After changing these values, agents will pick them up when they next fetch the configuration endpoint (on startup or periodic refresh).

**Related Resources:**

- [Client Resilience Recommendations](../api-reference-agent-auth.md#client-resilience-recommendations) in the API reference
- [GET /api/v1/client/health endpoint](../api-reference-agent-auth.md#get-apiv1clienthealth) documentation
- [Agent Configuration Best Practices](#agent-configuration)

---

## Log Analysis

### Parsing Structured Logs

Server logs use a structured format for easy parsing:

**Format:**

```
[ComponentType ID] Agent ID - Attack ID - Action - Details - Timestamp
```

**Examples:**

```
[Task 678] Agent 10 - Attack 123 - State change: running -> completed - Uncracked hashes: 1250 - 2026-01-06 15:30:45 UTC
[Attack 123] Abandoning attack for campaign 45, destroying 5 tasks: [678, 679, 680, 681, 682]
[TaskNotFound] Task 678 - Agent 10 - Reason: task_deleted - Task was removed when attack was abandoned or completed
```

### Using grep for Log Analysis

**Find all task lifecycle events for specific task:**

```bash
grep "Task 678" production.log
```

**Find all events for specific agent:**

```bash
grep "Agent 10" production.log
```

**Find all attack abandonments:**

```bash
grep "\[Attack.*Abandoning attack" production.log
```

**Find all task not found errors:**

```bash
grep "\[TaskNotFound\]" production.log
```

**Find all task assignment issues:**

```bash
grep "\[TaskAssignment\]" production.log
```

**Count 404 errors in last hour:**

```bash
grep "\[TaskNotFound\]" production.log | \
  grep "$(date -u +%Y-%m-%d\ %H)" | \
  wc -l
```

**Count idle agents with skip reasons in last hour:**

```bash
grep "\[TaskAssignment\] no_task_assigned" production.log | \
  grep "$(date -u +%Y-%m-%d\ %H)" | \
  wc -l
```

### Analyzing Patterns

**High 404 Rate:**

- Check for frequent attack abandonments
- Look for task reassignment patterns
- Verify agent timeout settings
- Check network stability

**Agents Not Receiving Tasks:**

- Check `[TaskAssignment]` logs for skip reasons
- Verify agent hash type and project configuration
- Review agent benchmark performance
- Ensure campaigns have uncracked hashes
- Check if campaigns are quarantined (quarantined campaigns are excluded from task assignment)

**Slow Task Completion:**

- Review task duration logs
- Check for paused tasks
- Verify hashcat performance
- Monitor system resources

**Frequent Task Reassignments:**

- Check agent heartbeat intervals
- Verify network stability
- Review task timeout configuration
- Look for agent crashes

### Common Log Patterns and Meanings

| Pattern                                                      | Meaning                                               | Action Required                                                            |
| ------------------------------------------------------------ | ----------------------------------------------------- | -------------------------------------------------------------------------- |
| `[Attack.*Abandoning attack.*destroying N tasks]`            | Attack abandoned, N tasks destroyed                   | Normal if occasional, investigate if frequent                              |
| `[Task.*State change.*-> running]`                           | Task accepted and started                             | Normal operation                                                           |
| `[Task.*State change.*-> completed]`                         | Task completed successfully                           | Normal operation                                                           |
| `[TaskNotFound].*task_deleted`                               | Agent tried to use deleted task                       | Normal, agent should request new work                                      |
| `[TaskNotFound].*task_not_assigned`                          | Agent tried to access other agent's task              | Check for configuration issues                                             |
| `[TaskNotFound].*task_invalid`                               | Invalid task ID used                                  | Possible client bug, investigate                                           |
| `[TaskAssignment] no_task_assigned.*no_available_attacks`    | No attacks match agent's configuration                | Check hash types and project assignments; verify campaigns not quarantined |
| `[TaskAssignment] no_task_assigned.*all_hashes_cracked`      | All available work is complete                        | Start new campaigns or adjust hash lists                                   |
| `[TaskAssignment] no_task_assigned.*performance_threshold`   | Agent too slow for available attacks                  | Review benchmarks or adjust thresholds                                     |
| Multiple `[TaskNotFound]` for same agent in short time       | Agent not recovering properly                         | Check agent configuration and code                                         |
| `[Attack.*Abandoning attack]` multiple times for same attack | Attack repeatedly abandoned and restarted             | Investigate root cause                                                     |
| `Circuit breaker open, server appears unresponsive`          | Circuit breaker protecting against cascading failures | Check server availability and health; agent will auto-recover              |
| `Circuit breaker open, skipping task retrieval`              | Agent avoiding failed requests during outage          | Normal during server downtime; no action needed                            |

### Tools for Log Analysis

**1. JSON Log Parser** (if using JSON format):

```bash
cat production.log | jq 'select(.component == "Task")'
```

**2. Log Aggregation Services:**

- Splunk
- ELK Stack (Elasticsearch, Logstash, Kibana)
- Datadog
- New Relic

**3. Custom Scripts:**

Create scripts to extract specific patterns:

```bash
#!/bin/bash
# task_error_summary.sh
# Summarizes task errors from logs

echo "Task Error Summary"
echo "=================="
echo ""

echo "Total TaskNotFound errors:"
grep -c "\[TaskNotFound\]" production.log

echo ""
echo "Breakdown by reason:"
grep "\[TaskNotFound\]" production.log | \
  sed -E 's/.*Reason: ([^ ]+).*/\1/' | \
  sort | uniq -c | sort -rn

echo ""
echo "Most affected agents:"
grep "\[TaskNotFound\]" production.log | \
  sed -E 's/.*Agent ([0-9]+).*/\1/' | \
  sort | uniq -c | sort -rn | head -10
```

---

## Getting Help

### When to Contact Administrators

**Contact immediately if:**

- Agent receives non-404 acceptance errors (indicates server/config issues)
- Multiple agents reporting same issues simultaneously
- Authentication failures persist after token refresh
- Server returns 5xx errors consistently despite retry logic
- Tasks are stuck in running state for >24 hours
- Circuit breaker remains open persistently (indicates sustained server problems)

**Information to Provide:**

1. **Agent Details:**

   - Agent ID
   - Agent version
   - Operating system
   - Hashcat version

2. **Error Details:**

   - Task ID(s) affected
   - Error messages and response bodies
   - Timestamps of errors
   - Frequency of errors

3. **Logs:**

   - Agent logs (last 100 lines before error)
   - Network connectivity status
   - System resource usage

4. **Context:**

   - What was the agent doing when error occurred?
   - Has anything changed recently (config, network, etc.)?
   - Is this a new issue or recurring problem?
   - Are other agents affected?

### Self-Service Diagnostics

Before contacting administrators, try:

1. **Check Server Status:**

   ```bash
   # Check health endpoint (no authentication required)
   curl -v http://server.example.com/api/v1/client/health

   # Alternative: check authenticated endpoint
   curl -I https://server.example.com/api/v1/client/authenticate
   ```

2. **Verify Authentication:**

   ```bash
   curl -H "Authorization: Bearer <token>" \
     https://server.example.com/api/v1/client/authenticate
   ```

3. **Test Task Assignment:**

   ```bash
   curl -H "Authorization: Bearer <token>" \
     https://server.example.com/api/v1/client/tasks/new
   ```

4. **Review Local Logs:**

   - Check for patterns in errors
   - Verify network connectivity logs
   - Review system resource usage

5. **Restart Agent:**

   - Sometimes a clean restart resolves transient issues
   - Monitor logs after restart for recurrence

---

## Additional Resources

- [API Reference Documentation](../api-reference-agent-auth.md)
- [Agent Setup Guide](agent-setup.md)
- [Server Log Format Specification](../development/logging-guide.md)
- [CipherSwarm Community Forum](https://community.cipherswarm.org)
- [GitHub Issues](https://github.com/unclesp1d3r/cipherswarm/issues)
