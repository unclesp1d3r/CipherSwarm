# Troubleshooting Guide

This guide covers system diagnostics, common issues, and solutions for CipherSwarm v2.

---

## Table of Contents

- [Quick Diagnostics: System Health Dashboard](#quick-diagnostics-system-health-dashboard)
- [Authentication Issues](#authentication-issues)
- [Project Access Issues](#project-access-issues)
- [Campaign Issues](#campaign-issues)
- [Attack Issues](#attack-issues)
- [Agent Issues](#agent-issues)
- [Task Issues](#task-issues)
- [Resource Issues](#resource-issues)
- [Performance Issues](#performance-issues)
- [Live Updates Issues](#live-updates-issues)
- [Getting Help](#getting-help)
- [Log Locations](#log-locations)
- [Common Error Messages](#common-error-messages)

---

## Quick Diagnostics: System Health Dashboard

CipherSwarm V2 includes a dedicated System Health Dashboard that provides real-time status information for all critical system components.

### Accessing the Health Dashboard

1. Navigate to **Admin** > **System Health** (administrators only)
2. The dashboard displays status cards for each service

### Service Status Cards

The health dashboard monitors four core services:

#### PostgreSQL

- **Status**: Connected / Disconnected
- **Metrics**: Connection pool status, response time
- **Common Issues**: Connection refused, max connections reached

#### Redis

- **Status**: Connected / Disconnected
- **Metrics**: Memory usage, connection count
- **Purpose**: Caching, session storage, Action Cable

#### MinIO (Object Storage)

- **Status**: Connected / Disconnected
- **Metrics**: Storage capacity, available space
- **Purpose**: File storage for wordlists, rules, hash lists

#### Application

- **Status**: Running / Degraded / Error
- **Metrics**: Uptime, memory usage, background job queue depth
- **Details**: Ruby version, Rails version, boot time

### Health Dashboard Features

- **Auto-refresh**: The dashboard refreshes automatically at configurable intervals
- **Manual Refresh**: Click the refresh button for an immediate status check
- **Diagnostics**: Each service card shows detailed diagnostic information
- **Error Details**: When a service is unhealthy, the card displays the specific error

### Using Health Data for Troubleshooting

The health dashboard is your first stop when something goes wrong:

1. **Check all service statuses** - A single failed service can cascade
2. **PostgreSQL down**: No data access, campaigns stall, agents cannot report
3. **Redis down**: Live updates stop, sessions may expire, caching disabled
4. **MinIO down**: Resource downloads fail, uploads fail, agents cannot get wordlists
5. **Application degraded**: Check memory usage and job queue depth

---

## Authentication Issues

### Cannot Log In

**Symptoms**: Login form rejects credentials or redirects back to the login page.

**Solutions**:

1. Verify your email and password are correct
2. Clear browser cache and cookies, or try incognito mode
3. Check if your account is locked or disabled (contact administrator)
4. Ensure the server is running (check the system health dashboard)

### Session Expired

**Symptoms**: You are unexpectedly logged out.

**Solutions**:

1. Log in again - sessions expire after a period of inactivity
2. If this happens frequently, check Redis status on the health dashboard
3. Contact your administrator if the session timeout is too short

### Agent Authentication Failures

**Symptoms**: Agent reports authentication errors in its logs.

**Solutions**:

1. Verify the agent token is correct and has not been rotated

2. Test authentication manually:

   ```bash
   curl -H "Authorization: Bearer <token>" \
     https://your-server.example.com/api/v1/client/authenticate
   ```

3. Check if the agent has been disabled in the web interface

4. See [Agent Setup](agent-setup.md#troubleshooting) for more details

---

## Project Access Issues

### Missing Projects

**Symptoms**: Expected projects do not appear in the project selector.

**Solutions**:

1. Verify you have been granted access to the project by an administrator
2. Refresh the page to reload the project list
3. Contact your administrator to request project access

### Permission Denied

**Symptoms**: "You are not authorized" error when accessing resources.

**Solutions**:

1. Ensure you have the correct role within the project
2. Check that the resource belongs to your currently selected project
3. Switch to the correct project using the project selector
4. Contact your administrator if you need elevated permissions

---

## Campaign Issues

### Campaign Won't Start

**Symptoms**: Campaign remains in pending state after creation.

**Possible Causes**:

1. **No attacks configured** - Add at least one attack to the campaign
2. **No agents available** - Verify agents are online and assigned to the project
3. **Priority preemption** - A higher-priority campaign may be using all agents
4. **Hash list processing** - The hash list may still be processing

**Solutions**:

1. Check the campaign has at least one attack
2. Go to **Agents** and verify at least one agent is online and in the correct project
3. Check if higher-priority campaigns are running
4. Verify the hash list status shows "Processed"

### Campaign Stuck with No Progress

**Symptoms**: Campaign shows running state but progress bar does not advance.

**Possible Causes**:

1. **Agent issues** - Agents may have crashed or lost connectivity
2. **Task errors** - Tasks may be failing repeatedly
3. **Resource access** - Agents cannot download required wordlists or rules

**Solutions**:

1. Check agent status in the **Agents** page
2. Look at the campaign error log for task failure messages
3. Verify resources (wordlists, rules) are accessible
4. Check the system health dashboard for MinIO status

### Campaign Shows Wrong Progress

**Symptoms**: Progress percentage seems incorrect or jumps unexpectedly.

**Explanation**: Progress is based on keyspace processed. Some attack types (like rule-based dictionary attacks) have keyspace estimates that adjust as processing proceeds. This can cause apparent jumps or reversals in progress.

---

## Attack Issues

### Attack Validation Errors

**Symptoms**: Cannot create or save an attack configuration.

**Solutions**:

1. Verify all required fields are filled in
2. Check that selected resources (wordlists, rules) exist and are accessible
3. Ensure the attack type is compatible with the hash type
4. Review any error messages displayed on the form

### Attack Stays in Pending State

**Symptoms**: Attack created but never starts running.

**Solutions**:

1. Ensure the parent campaign is started
2. Check that higher-priority attacks are not blocking this one
3. Verify agents have the required capabilities for this attack
4. Check that required resources are available for download

### Attack Fails Immediately

**Symptoms**: Attack transitions to failed state shortly after starting.

**Solutions**:

1. Check the task error messages in the campaign error log
2. Common causes: invalid mask syntax, missing wordlist, unsupported hash type
3. Verify the attack configuration matches hashcat requirements
4. Test the attack configuration manually with hashcat if possible

---

## Agent Issues

For detailed agent troubleshooting, see [Agent Troubleshooting](troubleshooting-agents.md).

### Quick Checks

- **Agent offline**: Check network connectivity and agent logs
- **Agent not accepting tasks**: Verify project assignment and agent state
- **Agent errors**: Check the agent error tab in the web interface

---

## Task Issues

CipherSwarm V2 provides task management actions directly from the web interface.

### Task Stuck in Pending

**Symptoms**: Tasks remain in pending state and are never picked up by agents.

**Possible Causes**:

1. No agents are available (all busy or offline)
2. Agent capabilities do not match task requirements
3. Agents are not assigned to the task's project

**Solutions**:

1. Check agent availability in the **Agents** page
2. Wait for agents to complete their current tasks
3. Verify agent project assignments match the campaign's project

### Task Failures

**Symptoms**: Tasks transition to failed state.

**Common Causes**:

- Agent crashes during processing
- hashcat returns an error (invalid arguments, GPU error)
- Network interruption during processing
- Resource files corrupted or inaccessible

**Solutions**:

1. Check the task detail page for the specific error message
2. Review agent logs for additional context
3. Try retrying the task (see Task Actions below)
4. If the error persists, review the attack configuration

### Task Cancellation

To cancel a running task:

1. Navigate to the task detail page
2. Click **Cancel**
3. The task will be stopped and its status updated
4. The keyspace will be reassigned to another task if agents are available

### Task Retry Procedures

To retry a failed task:

1. Navigate to the task detail page
2. Click **Retry**
3. The task is reset and made available for an agent to pick up
4. The retry count is incremented for tracking purposes

### Task Reassignment

To reassign a task to a different agent:

1. Navigate to the task detail page
2. Click **Reassign**
3. The task is released from the current agent
4. An available agent will pick up the task automatically

### Task Status History

Each task maintains a status history showing all state transitions:

- When the task was created
- When it was assigned to an agent
- Any pauses, errors, or retries
- When it completed or failed

---

## Resource Issues

### Upload Failures

**Symptoms**: File upload fails or hangs.

**Solutions**:

1. Check file size against the configured maximum
2. Verify the file format is supported
3. Check MinIO status on the system health dashboard
4. Try a smaller file to isolate the issue
5. Check browser console for JavaScript errors

### Resource Access Denied

**Symptoms**: Agents report they cannot download resources.

**Solutions**:

1. Verify the resource is assigned to the correct project
2. Check MinIO connectivity on the system health dashboard
3. Verify the agent's token has not expired
4. Check server logs for presigned URL generation errors

### Missing Resources

**Symptoms**: Resources that existed previously are no longer accessible.

**Solutions**:

1. Check if the resource was deleted by another user
2. Verify you are in the correct project context
3. Check MinIO storage health for potential data loss
4. Review audit logs for resource deletion events

---

## Performance Issues

### Slow Web Interface

**Symptoms**: Pages load slowly, actions take a long time to complete.

**Solutions**:

1. Check the system health dashboard for service issues
2. Verify PostgreSQL is not under heavy load
3. Check Redis status (caching may be down)
4. Reduce the number of concurrent browser tabs to CipherSwarm
5. Check network latency to the server

### High Server Resource Usage

**Symptoms**: Server CPU or memory usage is consistently high.

**Solutions**:

1. Check Sidekiq job queue depth on the health dashboard
2. Review active campaigns for unusually large operations
3. Monitor database query performance
4. Consider scaling resources if usage is consistently high

### Slow Agent Performance

**Symptoms**: Agents are cracking slower than expected.

**Solutions**:

1. Check GPU temperatures (throttling starts around 80-90C)
2. Verify agent workload settings are appropriate
3. Check for competing processes on the agent machine
4. See [Performance Optimization](optimization.md) for tuning guidance

---

## Live Updates Issues

### Real-Time Updates Not Working

**Symptoms**: Dashboard and campaign pages do not update automatically.

**Solutions**:

1. Check browser console for WebSocket connection errors
2. Verify Redis is running (shown on health dashboard)
3. Try refreshing the page to re-establish the connection
4. Check if your network/proxy blocks WebSocket connections
5. CipherSwarm automatically falls back to polling if WebSockets are unavailable

### Stale Data Warning

**Symptoms**: A "Stale data" warning appears on the page.

**Explanation**: This warning indicates that the live update connection was lost for more than 30 seconds. The displayed data may be out of date.

**Solutions**:

1. Refresh the page to get the latest data
2. Check network connectivity
3. Verify server health via the system health dashboard

---

## Getting Help

### When to Contact Administrators

Contact your administrator if:

- You cannot resolve an issue using this guide
- Multiple users are experiencing the same problem
- System health dashboard shows service failures
- You suspect a security issue

### What Information to Provide

When reporting an issue, include:

1. **Description**: What you were trying to do and what happened
2. **Steps to Reproduce**: How to recreate the issue
3. **Error Messages**: Exact text of any error messages
4. **Screenshots**: If the issue is visual
5. **Timestamps**: When the issue occurred
6. **Browser/OS**: Your browser version and operating system

---

## Log Locations

### Server Logs

| Log File              | Purpose                                 |
| --------------------- | --------------------------------------- |
| `log/development.log` | Development environment application log |
| `log/production.log`  | Production environment application log  |
| `log/sidekiq.log`     | Background job processing log           |

### Docker Logs

```bash
# Application logs
docker logs cipherswarm-web

# Sidekiq logs
docker logs cipherswarm-sidekiq

# PostgreSQL logs
docker logs cipherswarm-postgres

# Redis logs
docker logs cipherswarm-redis
```

### Agent Logs

See [Agent Troubleshooting](troubleshooting-agents.md#log-analysis) for agent-specific log locations and analysis.

---

## Common Error Messages

| Error Message                   | Meaning                                | Solution                                       |
| ------------------------------- | -------------------------------------- | ---------------------------------------------- |
| "You are not authorized"        | Missing permissions for this action    | Check role and project access                  |
| "Record not found"              | Resource was deleted or doesn't exist  | Verify resource exists, check project context  |
| "Hash list is still processing" | Hash list upload hasn't completed      | Wait for processing, check job queue           |
| "No agents available"           | No online agents in this project       | Register agents or check agent status          |
| "Resource download failed"      | Agent couldn't download wordlist/rules | Check MinIO status and agent connectivity      |
| "Invalid attack configuration"  | Attack parameters are incorrect        | Review attack settings, check hash type compat |
| "Connection refused"            | A backend service is down              | Check system health dashboard                  |
| "Task expired"                  | Agent took too long to complete a task | Check agent performance, increase timeout      |

---

## Related Guides

- [Common Issues](common-issues.md) - Quick fixes for frequently encountered problems
- [Agent Troubleshooting](troubleshooting-agents.md) - Detailed agent diagnostics
- [FAQ](faq.md) - Frequently asked questions
- [Performance Optimization](optimization.md) - System and agent tuning
