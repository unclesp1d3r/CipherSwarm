# CipherSwarm Agent & Authentication API Reference

This document provides a comprehensive reference for all CipherSwarm API endpoints that are NOT part of the `/api/v1/web/*` or `/api/v1/control/*` interfaces. These endpoints are primarily used by CipherSwarm agents and authentication systems.

---

## Table of Contents

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=2 --minlevel=1 -->

- [CipherSwarm Agent & Authentication API Reference](#cipherswarm-agent--authentication-api-reference)
  - [Table of Contents](#table-of-contents)
  - [Authentication](#authentication)
  - [General Authentication Endpoints](#general-authentication-endpoints)
  - [Agent Configuration](#agent-configuration)
  - [Agent Authentication](#agent-authentication)
  - [Agent Management](#agent-management)
  - [Task Management](#task-management)
  - [Attack Management](#attack-management)
  - [Cracker Management](#cracker-management)
  - [Error Handling](#error-handling)
  - [API Patterns](#api-patterns)
  - [API Version Compatibility](#api-version-compatibility)
  - [Security Considerations](#security-considerations)
  - [Performance Notes](#performance-notes)
  - [Agent Implementation Best Practices](#agent-implementation-best-practices)

<!-- mdformat-toc end -->

---

## Authentication

All agent API endpoints require authentication via the `Authorization` header:

```http
Authorization: Bearer <agent_token>
```

Agent tokens follow the format: `csa_<agent_id>_<random_string>`

## General Authentication Endpoints

### POST `/api/v1/auth/login`

**Summary:** User login with email and password

**Parameters:**

- `email` (query, required): User email address
- `password` (query, required): User password

**Responses:**

- `200`: Successful login - Returns authentication token
- `422`: Validation error

**Example:**

```http
POST /api/v1/auth/login?email=user@example.com&password=secret123
```

### POST `/api/v1/auth/jwt/login`

**Summary:** JWT-based login

**Request Body:** `application/x-www-form-urlencoded`

- Username/password form data

**Responses:**

- `200`: Successful login - Returns JWT token
- `422`: Validation error

## Agent Configuration

### GET `/api/v1/client/configuration`

**Summary:** Get agent configuration

**Description:** Returns the configuration for the agent that has been set by the administrator on the server. The configuration is stored in the database and can be updated by the administrator on the server and is global, but specific to the individual agent. Client should cache the configuration and only request a new configuration if the agent is restarted or if the configuration has changed.

**Parameters:**

- `Authorization` (header, required): Bearer token

**Responses:**

- `200`: Successful - Returns `AgentConfigurationResponse`
- `401`: Unauthorized
- `404`: Agent not found
- `422`: Validation error

### GET `/api/v1/configuration`

**Summary:** Get agent configuration (legacy v1 endpoint)

**Description:** Legacy endpoint for agent configuration retrieval. Same functionality as `/api/v1/client/configuration`.

**Parameters:**

- `Authorization` (header, required): Bearer token

**Responses:**

- `200`: Successful - Returns `AgentConfigurationResponse`
- `401`: Unauthorized
- `404`: Agent not found
- `422`: Validation error

## Agent Authentication

### GET `/api/v1/client/authenticate`

**Summary:** Authenticate client

**Description:** Authenticates the client. This is used to verify that the client is able to connect to the server.

**Parameters:**

- `Authorization` (header, required): Bearer token

**Responses:**

- `200`: Successful - Returns `AgentAuthenticateResponse` with `authenticated: true` and `agent_id`
- `401`: Unauthorized - Returns `ErrorObject` with "Bad credentials" message
- `422`: Validation error

**Example Response:**

```json
{
  "authenticated": true,
  "agent_id": 2624
}
```

### GET `/api/v1/authenticate`

**Summary:** Authenticate client (legacy v1 endpoint)

**Description:** Legacy endpoint for client authentication. Same functionality as `/api/v1/client/authenticate`.

**Parameters:**

- `Authorization` (header, required): Bearer token

**Responses:**

- `200`: Successful - Returns `AgentAuthenticateResponse`
- `401`: Unauthorized - Returns `ErrorObject`
- `422`: Validation error

## Agent Management

### GET `/api/v1/client/agents/{id}`

**Summary:** Get agent by ID

**Description:** Get agent details by ID. Requires agent authentication.

**Parameters:**

- `id` (path, required): Agent ID
- `Authorization` (header, required): Bearer token

**Responses:**

- `200`: Successful - Returns `AgentResponseV1`
- `422`: Validation error

### PUT `/api/v1/client/agents/{id}`

**Summary:** Update agent

**Description:** Update agent information. Requires agent authentication.

**Parameters:**

- `id` (path, required): Agent ID

**Request Body:** `AgentUpdateV1` schema

**Responses:**

- `200`: Successful - Returns `AgentResponseV1`
- `422`: Validation error

### POST `/api/v1/client/agents/{id}/submit_benchmark`

**Summary:** Submit agent benchmark results

**Description:** Submit agent benchmark results. Requires agent authentication.

**Parameters:**

- `id` (path, required): Agent ID
- `Authorization` (header, required): Bearer token

**Request Body:** `AgentBenchmark` schema

**Responses:**

- `204`: Successful - No content
- `422`: Validation error

### POST `/api/v1/client/agents/{id}/submit_error`

**Summary:** Submit agent error

**Description:** Submit agent error. Requires agent authentication.

**Parameters:**

- `id` (path, required): Agent ID
- `Authorization` (header, required): Bearer token

**Request Body:** `AgentErrorV1` schema

**Responses:**

- `204`: Successful - No content
- `422`: Validation error

### POST `/api/v1/client/agents/{id}/shutdown`

**Summary:** Shutdown agent

**Description:** Shutdown agent. Requires agent authentication.

**Parameters:**

- `id` (path, required): Agent ID
- `Authorization` (header, required): Bearer token

**Responses:**

- `204`: Successful - No content
- `422`: Validation error

### POST `/api/v1/client/agents/{id}/heartbeat`

**Summary:** Agent heartbeat

**Description:** Agent sends a heartbeat to update its status and last seen timestamp. Contract-compliant endpoint.

**Parameters:**

- `id` (path, required): Agent ID
- `Authorization` (header, required): Bearer token

**Request Body:** `AgentHeartbeatRequest` schema

**Responses:**

- `204`: Successful - No content
- `422`: Validation error

## Task Management

### GET `/api/v1/client/tasks/new`

**Summary:** Request a new task from server

**Description:** Request a new task from the server, if available. Compatibility layer for v1 API.

**Parameters:**

- `Authorization` (header, required): Bearer token

**Responses:**

- `200`: Successful - Returns task data
- `422`: Validation error

### GET `/api/v1/client/tasks/{id}`

**Summary:** Request task information

**Description:** Request the task information from the server. Requires agent authentication and assignment.

**Parameters:**

- `id` (path, required): Task ID
- `Authorization` (header, required): Bearer token

**Responses:**

- `200`: Successful - Returns `TaskOutV1`
- `404`: Task not found
- `401`: Unauthorized
- `403`: Forbidden
- `422`: Validation error

### POST `/api/v1/client/tasks/{id}/accept_task`

**Summary:** Accept task

**Description:** Accept an offered task from the server. Sets the task status to running and assigns it to the agent.

**Parameters:**

- `id` (path, required): Task ID
- `Authorization` (header, required): Bearer token

**Responses:**

- `204`: Task accepted successfully
- `422`: Task already completed
- `404`: Task not found for agent
- `401`: Unauthorized
- `403`: Forbidden

### POST `/api/v1/client/tasks/{id}/submit_status`

**Summary:** Submit task status update

**Description:** Submit a status update for a running task. This is the main status heartbeat endpoint for agents.

**Parameters:**

- `id` (path, required): Task ID
- `Authorization` (header, required): Bearer token

**Request Body:** `TaskStatusUpdate` schema

**Responses:**

- `204`: Status received successfully
- `202`: Status received successfully, but stale
- `410`: Status received successfully, but task paused
- `422`: Malformed status data
- `404`: Task not found
- `401`: Unauthorized
- `403`: Forbidden
- `409`: Task not running

### POST `/api/v1/client/tasks/{id}/progress`

**Summary:** Update task progress

**Description:** Agents send progress updates for a task. Compatibility layer for v1 API.

**Parameters:**

- `id` (path, required): Task ID
- `Authorization` (header, required): Bearer token

**Request Body:** `TaskProgressUpdate` schema

**Responses:**

- `204`: Successful - No content
- `422`: Validation error

### POST `/api/v1/client/tasks/{id}/submit_crack`

**Summary:** Submit cracked hash result

**Description:** Submit a cracked hash result for a task. Compatibility layer for v1 API.

**Parameters:**

- `id` (path, required): Task ID
- `Authorization` (header, required): Bearer token

**Request Body:** `HashcatResult` schema

**Responses:**

- `200`: Successful - Returns confirmation
- `422`: Validation error

### POST `/api/v1/client/tasks/{id}/exhausted`

**Summary:** Notify of exhausted task

**Description:** Notify the server that the task is exhausted. This will mark the task as completed.

**Parameters:**

- `id` (path, required): Task ID
- `Authorization` (header, required): Bearer token

**Responses:**

- `204`: Successful - No content
- `404`: Task not found
- `401`: Unauthorized
- `403`: Forbidden
- `422`: Task already completed or exhausted

### POST `/api/v1/client/tasks/{id}/abandon`

**Summary:** Abandon task

**Description:** Abandon a task. This will mark the task as abandoned. Usually used when the client is unable to complete the task.

**Parameters:**

- `id` (path, required): Task ID
- `Authorization` (header, required): Bearer token

**Responses:**

- `204`: Successful - No content
- `422`: Already completed
- `404`: Task not found
- `401`: Unauthorized
- `403`: Forbidden

### GET `/api/v1/client/tasks/{id}/get_zaps`

**Summary:** Get completed hashes

**Description:** Gets the completed hashes for a task. This is a text file that should be added to the monitored directory to remove the hashes from the list during runtime.

**Parameters:**

- `id` (path, required): Task ID
- `Authorization` (header, optional): Bearer token

**Responses:**

- `200`: Successful - Returns text/plain content
- `422`: Already completed
- `404`: Task not found
- `401`: Unauthorized
- `403`: Forbidden

## Attack Management

### GET `/api/v1/client/attacks/{id}`

**Summary:** Get attack by ID

**Description:** Returns an attack by id. This is used to get the details of an attack.

**Parameters:**

- `id` (path, required): Attack ID
- `Authorization` (header, required): Bearer token

**Responses:**

- `200`: Successful - Returns `AttackOutV1`
- `422`: Validation error

### GET `/api/v1/client/attacks/{id}/hash_list`

**Summary:** Get hash list for attack

**Description:** Returns the hash list for an attack as a text file. Each line is a hash value. Requires agent authentication.

**Parameters:**

- `id` (path, required): Attack ID
- `Authorization` (header, required): Bearer token

**Responses:**

- `200`: Successful - Returns text/plain content
- `404`: Record not found
- `401`: Unauthorized
- `403`: Forbidden
- `422`: Validation error

## Cracker Management

### GET `/api/v1/client/crackers/check_for_cracker_update`

**Summary:** Check for cracker update

**Description:** Checks for an update to the cracker and returns update info if available.

**Parameters:**

- `version` (query, required): Current cracker version (semver)
- `operating_system` (query, required): Operating system (windows, linux, darwin)

**Responses:**

- `200`: Successful - Returns `CrackerUpdateResponse`
- `400`: Bad request - Returns `ErrorObject`
- `401`: Unauthorized - Returns `ErrorObject`
- `422`: Validation error

**Example:**

```http
GET /api/v1/client/crackers/check_for_cracker_update?version=6.2.6&operating_system=linux
```

## Error Handling

### Common Error Responses

**401 Unauthorized:**

```json
{
  "error": "Bad credentials"
}
```

**422 Validation Error:**

```json
{
  "detail": [
    {
      "loc": [
        "body",
        "field"
      ],
      "msg": "field required",
      "type": "value_error.missing"
    }
  ]
}
```

**404 Not Found:**

```json
{
  "detail": "Record not found"
}
```

### Enhanced Task Error Responses

When task-related 404 errors occur, the API may provide enhanced error responses with optional metadata to help clients understand the cause and take appropriate action:

**Task Not Found - Task Deleted:**

```json
{
  "error": "Record not found",
  "reason": "task_deleted",
  "details": "Task was removed when attack was abandoned or completed"
}
```

**Task Not Found - Task Not Assigned:**

```json
{
  "error": "Record not found",
  "reason": "task_not_assigned",
  "details": "Task belongs to another agent"
}
```

**Task Not Found - Invalid Task ID:**

```json
{
  "error": "Record not found",
  "reason": "task_invalid",
  "details": "Task ID does not exist"
}
```

### Handling Task Lifecycle Errors

Tasks can be removed or reassigned for several reasons:

1. **Attack Abandonment**: When an attack is abandoned, all associated tasks are destroyed immediately
2. **Task Reassignment**: Tasks may be reassigned to other agents if not accepted in time
3. **Task Completion**: Completed tasks may be removed from the system
4. **Server-Side Cleanup**: Tasks may be cleaned up during maintenance operations

**Recommended Client Behavior:**

When receiving a 404 error for a task operation:

1. **Stop Retrying**: Do not retry the same task ID indefinitely
2. **Exponential Backoff**: Implement exponential backoff starting at 1 second, maximum 60 seconds
3. **Request New Work**: After 3 consecutive 404 errors for the same task, abandon the reference and request a new task via `GET /api/v1/client/tasks/new`
4. **Log the Error**: Log all 404 errors with task ID and agent ID for debugging
5. **Monitor Patterns**: Track 404 error rates to identify systemic issues

**Example Recovery Flow:**

```
1. Agent receives 404 for submit_status on Task 123
2. Agent waits 1 second (exponential backoff attempt 1)
3. Agent retries submit_status → 404 again
4. Agent waits 2 seconds (exponential backoff attempt 2)
5. Agent retries submit_status → 404 again
6. Agent waits 4 seconds (exponential backoff attempt 3)
7. Agent abandons Task 123 reference
8. Agent requests new task: GET /api/v1/client/tasks/new
9. Agent receives Task 456 and continues work
```

**Interpreting Reason Codes:**

- `task_deleted`: The task was destroyed server-side, likely due to attack abandonment. Request new work immediately.
- `task_not_assigned`: The task exists but is assigned to another agent. Request new work immediately.
- `task_invalid`: The task ID does not exist. This may indicate a client bug. Request new work immediately.
- No reason field: Legacy error response format. Treat as `task_deleted` and request new work.

### Error Codes by Endpoint

- **Authentication endpoints**: 401 (unauthorized), 422 (validation)
- **Agent endpoints**: 401 (unauthorized), 403 (forbidden), 404 (not found), 422 (validation)
- **Task endpoints**: 401 (unauthorized), 403 (forbidden), 404 (not found), 409 (conflict), 410 (gone), 422 (validation)
- **Attack endpoints**: 401 (unauthorized), 403 (forbidden), 404 (not found), 422 (validation)

## API Patterns

### Agent Lifecycle

1. **Authentication**: `GET /api/v1/client/authenticate`
2. **Configuration**: `GET /api/v1/client/configuration`
3. **Heartbeat**: `POST /api/v1/client/agents/{id}/heartbeat`
4. **Task Request**: `GET /api/v1/client/tasks/new`
5. **Task Accept**: `POST /api/v1/client/tasks/{id}/accept_task`
6. **Status Updates**: `POST /api/v1/client/tasks/{id}/submit_status`
7. **Submit Results**: `POST /api/v1/client/tasks/{id}/submit_crack`
8. **Task Completion**: `POST /api/v1/client/tasks/{id}/exhausted`
9. **Shutdown**: `POST /api/v1/client/agents/{id}/shutdown`

### Task States

- **New**: Task is available for assignment
- **Running**: Task is being executed by an agent
- **Paused**: Task execution is temporarily stopped
- **Completed**: Task has finished successfully
- **Exhausted**: Task keyspace has been fully explored
- **Abandoned**: Task was abandoned by the agent

### Authentication Flow

1. Agent obtains token during registration
2. All API calls include `Authorization: Bearer <token>`
3. Server validates token and returns appropriate response
4. 401 responses indicate invalid/expired tokens

### Status Updates

Agents should send periodic status updates while executing tasks:

- **Frequency**: Every 10-30 seconds during active execution
- **Content**: Progress information, hash rate, temperature, etc.
- **Response Codes**:
  - 204: Continue execution
  - 202: Status accepted but stale
  - 410: Task paused, stop execution
  - 404: Task not found, abandon and request new work

**Handling 404 Errors on Status Updates:**

If `submit_status` returns a 404 error:

1. The task no longer exists on the server
2. Stop processing immediately and don't retry
3. Abandon the current task reference locally
4. Request a new task via `GET /api/v1/client/tasks/new`
5. Implement exponential backoff (1s, 2s, 4s) before final abandonment
6. Log the error with task ID and agent ID for diagnostics

**Best Practices for Status Updates:**

- Always check response status codes before continuing
- Don't retry indefinitely on 404 errors (max 3 attempts)
- Use exponential backoff starting at 1 second, maximum 60 seconds
- Log all status update failures for debugging
- Monitor error rates to detect systemic issues

### Error Reporting

Agents should report errors using the dedicated error endpoint:

- **Endpoint**: `POST /api/v1/client/agents/{id}/submit_error`
- **Content**: Structured error information
- **Timing**: Immediately when errors occur

### Resource Management

- **Hash Lists**: Downloaded via `GET /api/v1/client/attacks/{id}/hash_list`
- **Completed Hashes**: Retrieved via `GET /api/v1/client/tasks/{id}/get_zaps`
- **Updates**: Checked via `GET /api/v1/client/crackers/check_for_cracker_update`

## API Version Compatibility

These endpoints represent the v1 Agent API, which is locked to the contract defined in `contracts/v1_api_swagger.json`. All endpoints must maintain exact compatibility with the legacy Ruby-on-Rails version of CipherSwarm.

Key compatibility requirements:

- Field names and types must match exactly
- Response schemas are immutable
- Breaking changes are prohibited
- New functionality should be added to v2 API when available

## Security Considerations

- All agent communications require valid bearer tokens
- Tokens are bound to specific agents and cannot be shared
- Failed authentication attempts should be logged
- Rate limiting may be applied to prevent abuse
- All communications should use HTTPS in production

## Performance Notes

- Configuration should be cached locally by agents
- Heartbeat frequency should be configurable
- Status updates should be batched when possible
- Large hash lists may require streaming or chunked downloads
- Error reporting should be throttled to prevent spam

## Agent Implementation Best Practices

### Error Handling and Recovery

**Exponential Backoff Strategy:**

When encountering 404 errors for task operations:

1. First retry: Wait 1 second
2. Second retry: Wait 2 seconds
3. Third retry: Wait 4 seconds
4. After 3 consecutive 404s for the same task: Abandon task reference and request new work
5. Maximum backoff: 60 seconds between retries

**Task Loss Recovery:**

- After detecting a lost task (404 error), immediately request new work via `/api/v1/client/tasks/new`
- Don't retry indefinitely on non-existent tasks
- Implement local task state tracking to detect inconsistencies
- Log all task loss events with timestamps and task IDs

**Error Logging Requirements:**

- Log all 404 errors with: task ID, agent ID, operation type, timestamp
- Log task state transitions locally for correlation with server logs
- Include server response bodies in logs for debugging
- Use structured logging format (JSON) for easy parsing

### Monitoring and Diagnostics

**Health Checks:**

- Implement regular self-health checks independent of heartbeats
- Monitor task assignment rates and success rates
- Track 404 error rates and patterns
- Alert on high error rates (>5% of requests)

**Server Log Correlation:**

- Server logs include structured task lifecycle events
- Match client task IDs with server task IDs for debugging
- Look for "Task not found" patterns in server logs
- Contact administrators if repeated task loss occurs

### Task Validation

**Before Starting Expensive Operations:**

- Validate task existence before downloading large hash lists
- Check task state before starting compute-intensive work
- Implement local task expiration tracking
- Request task updates periodically for long-running operations

### Configuration

**Recommended Settings:**

- Heartbeat interval: 30-60 seconds
- Status update interval: 10-30 seconds (during active work)
- Task timeout: Configurable, default 24 hours
- Max retry attempts: 3 for 404 errors
- Backoff multiplier: 2x (exponential)
- Max backoff: 60 seconds

### Common Scenarios and Solutions

**Scenario 1: Attack Abandoned While Agent Processing**

- **Symptom**: Agent receives 404 on status update
- **Cause**: Server abandoned attack, destroying all tasks
- **Solution**: Stop processing, request new task immediately
- **Prevention**: Check for stale tasks before expensive operations

**Scenario 2: Network Interruption Causing Stale References**

- **Symptom**: Multiple 404 errors after network recovery
- **Cause**: Tasks reassigned during network outage
- **Solution**: Implement exponential backoff, request new tasks
- **Prevention**: Detect network issues early, implement connection monitoring

**Scenario 3: Multiple Agents Competing for Same Task**

- **Symptom**: 404 with reason "task_not_assigned"
- **Cause**: Task was claimed by another agent
- **Solution**: Request new task immediately
- **Prevention**: Accept tasks promptly after receiving them

**Scenario 4: Server Restart Causing Task Reassignment**

- **Symptom**: All tasks return 404 after server maintenance
- **Cause**: Server state reset, tasks reassigned
- **Solution**: Detect server downtime, re-authenticate and request new tasks
- **Prevention**: Monitor server availability, implement graceful reconnection

### Debugging Task Lifecycle Issues

**Server-Side Logs to Check:**

- `[Attack <id>] Abandoning attack` - Indicates attack abandonment
- `[Task <id>] Agent <id> - State change` - Shows task state transitions
- `[TaskNotFound]` - Shows task lookup failures with reason codes

**Client-Side Data to Collect:**

- Task ID and agent ID for all 404 errors
- Timestamps of task acceptance and loss
- Network conditions at time of error
- Task processing duration before 404

**Correlation Steps:**

1. Find task ID in client logs
2. Search server logs for same task ID
3. Look for attack abandonment events
4. Check for task state transitions
5. Identify root cause (abandonment, reassignment, completion)

For more detailed troubleshooting information, see the [Agent Troubleshooting Guide](troubleshooting-agents.md).
