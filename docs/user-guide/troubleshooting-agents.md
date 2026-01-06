# Agent Troubleshooting Guide

This guide provides detailed troubleshooting steps for common agent issues, with a focus on task lifecycle errors and recovery procedures.

---

## Table of Contents

- [Task Not Found Errors](#task-not-found-errors)
- [Agent Recovery Procedures](#agent-recovery-procedures)
- [Server-Side Diagnostics](#server-side-diagnostics)
- [Best Practices](#best-practices)
- [Common Scenarios](#common-scenarios)
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

### When to Restart an Agent

**Restart Required:**

- Agent enters an unrecoverable error state
- Memory leaks detected (monitor memory usage)
- Configuration changes applied
- Agent reports persistent authentication failures
- Multiple consecutive task losses (>10 in 1 hour)

**Restart NOT Required:**

- Single task loss (404 error) - automatic recovery should handle this
- Temporary network issues - agent should reconnect automatically
- Server returns 5xx errors occasionally - implement retry logic
- Status update returns 202 (stale) or 410 (paused) - these are normal operations

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
```

**Why These Settings:**

- **heartbeat_interval**: Keeps server aware of agent status without overwhelming it
- **status_update_interval**: Provides timely progress updates
- **task_timeout**: Allows long-running tasks while preventing indefinite hangs
- **max_404_retries**: Balances recovery attempts with quick failure detection
- **retry_backoff**: Prevents overwhelming server during issues
- **request_new_task_interval**: Regular check for work without excessive polling

### Monitoring Agent Health

**Metrics to Track:**

1. **Task Success Rate**: `(completed_tasks / total_assigned_tasks) * 100`

   - Target: >95%
   - Alert: \<90%

2. **404 Error Rate**: `(404_errors / total_requests) * 100`

   - Target: \<1%
   - Alert: >5%

3. **Average Task Duration**: Time from accept to completion

   - Track for anomalies
   - Alert on sudden increases

4. **Network Latency**: Round-trip time for API requests

   - Target: \<500ms
   - Alert: >2000ms

5. **Memory Usage**: Agent memory consumption

   - Target: Stable over time
   - Alert on continuous growth (potential leak)

### Alert Configuration

**Critical Alerts:**

- Agent offline for >10 minutes
- 404 error rate >10% in 5-minute window
- Authentication failures
- No tasks completed in last hour (when tasks available)

**Warning Alerts:**

- 404 error rate >5% in 15-minute window
- Task success rate \<95%
- High memory usage (>80% of limit)
- Network latency >1000ms

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

**Resolution:**

1. Detect network outage (failed heartbeat)
2. When network recovers, re-authenticate with server
3. Abandon all local task references
4. Request new tasks
5. Resume normal operations

**Prevention:**

- Implement network connectivity monitoring
- Detect outages early and enter offline mode
- Don't accumulate stale task references
- Re-authenticate after network issues
- Implement connection retry logic with backoff

### Scenario 3: Multiple Agents Competing for Same Task

**Symptoms:**

- Agent requests new task
- Agent receives task assignment
- Agent attempts to accept task
- Server returns 404 with `reason: "task_not_assigned"`

**Cause:**

- Multiple agents requested tasks simultaneously
- Server assigned same task to multiple agents (race condition)
- One agent accepted faster, others receive 404

**Server Logs Show:**

```
[Task 700] Agent 10 - Attack 123 - State change: pending -> running - Task accepted and running
[TaskNotFound] Task 700 - Requested by Agent 11 - Assigned to Agent 10 - Reason: task_not_assigned
```

**Resolution:**

1. Agent receives 404 on accept_task
2. Agent immediately requests new task
3. Agent does not retry accepting the same task
4. Agent continues normally with new task

**Prevention:**

- Accept tasks promptly after receiving them (within 10 seconds)
- Don't delay between receiving and accepting
- Implement atomic task claiming logic on server
- Monitor for frequent task conflicts

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

**Resolution:**

1. Detect widespread 404 errors across agents
2. Re-authenticate all agents
3. Abandon all current task references
4. Request new tasks for all agents
5. Resume normal operations

**Prevention:**

- Monitor server uptime and health
- Implement graceful server restart procedures
- Notify agents of planned maintenance
- Persist task assignments to database
- Implement server restart detection in agents

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

**Count 404 errors in last hour:**

```bash
grep "\[TaskNotFound\]" production.log | \
  grep "$(date -u +%Y-%m-%d\ %H)" | \
  wc -l
```

### Analyzing Patterns

**High 404 Rate:**

- Check for frequent attack abandonments
- Look for task reassignment patterns
- Verify agent timeout settings
- Check network stability

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

| Pattern                                                      | Meaning                                   | Action Required                               |
| ------------------------------------------------------------ | ----------------------------------------- | --------------------------------------------- |
| `[Attack.*Abandoning attack.*destroying N tasks]`            | Attack abandoned, N tasks destroyed       | Normal if occasional, investigate if frequent |
| `[Task.*State change.*-> running]`                           | Task accepted and started                 | Normal operation                              |
| `[Task.*State change.*-> completed]`                         | Task completed successfully               | Normal operation                              |
| `[TaskNotFound].*task_deleted`                               | Agent tried to use deleted task           | Normal, agent should request new work         |
| `[TaskNotFound].*task_not_assigned`                          | Agent tried to access other agent's task  | Check for configuration issues                |
| `[TaskNotFound].*task_invalid`                               | Invalid task ID used                      | Possible client bug, investigate              |
| Multiple `[TaskNotFound]` for same agent in short time       | Agent not recovering properly             | Check agent configuration and code            |
| `[Attack.*Abandoning attack]` multiple times for same attack | Attack repeatedly abandoned and restarted | Investigate root cause                        |

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

- Agent receives 404 errors at >10% rate for >15 minutes
- Multiple agents reporting same issues simultaneously
- Authentication failures persist after token refresh
- Server returns 5xx errors consistently
- Tasks are stuck in running state for >24 hours

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
- [Agent Configuration Guide](agent-configuration.md)
- [Server Log Format Specification](../development/logging.md)
- [CipherSwarm Community Forum](https://community.cipherswarm.org)
- [GitHub Issues](https://github.com/unclesp1d3r/cipherswarm/issues)
