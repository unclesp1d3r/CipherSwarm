# Agent API (v1)

## Overview

The Agent API (`/api/v1/client/*`) is used by distributed CipherSwarm agents to communicate with the server. This API follows the legacy Ruby-on-Rails specification defined in `contracts/v1_api_swagger.json` and maintains strict backward compatibility.

Agents use this API to:

- Register and authenticate with the server
- Receive task assignments and attack configurations
- Submit progress updates and results
- Report errors and performance metrics
- Download attack resources and cracker binaries

## Authentication

All Agent API endpoints (except `/client/authenticate`) require Bearer token authentication:

```http
Authorization: Bearer csa_<agent_id>_<random_string>
```

Tokens are automatically generated during agent registration and are unique per agent.

## Base URL

All Agent API endpoints are prefixed with `/api/v1/client/` or `/api/v1/` (legacy compatibility).

## Endpoints

### Authentication & Configuration

#### `GET /api/v1/client/authenticate`

Verify agent authentication and retrieve agent ID.

**Response:** `AgentAuthenticateResponse`

- `authenticated: bool` - Authentication status
- `agent_id: int` - The authenticated agent's ID

#### `GET /api/v1/client/configuration`

Retrieve agent-specific configuration settings.

**Response:** `AgentConfigurationResponse`

- `config: AdvancedAgentConfiguration` - Agent configuration object
- `api_version: int` - API version number

### Agent Management

#### `GET /api/v1/client/agents/{id}`

Retrieve agent details by ID.

**Parameters:**

- `id: int` - Agent ID

**Response:** `AgentResponseV1`

#### `PUT /api/v1/client/agents/{id}`

Update agent information.

**Parameters:**

- `id: int` - Agent ID

**Request Body:** `AgentUpdateV1`

**Response:** `AgentResponseV1`

#### `POST /api/v1/client/agents/{id}/heartbeat`

Send agent heartbeat to update status and last seen timestamp.

**Parameters:**

- `id: int` - Agent ID

**Request Body:** `AgentHeartbeatRequest`

**Response:** `204 No Content`

#### `POST /api/v1/client/agents/{id}/submit_benchmark`

Submit agent benchmark results.

**Parameters:**

- `id: int` - Agent ID

**Request Body:** `AgentBenchmark`

**Response:** `204 No Content`

#### `POST /api/v1/client/agents/{id}/submit_error`

Report agent errors to the server.

**Parameters:**

- `id: int` - Agent ID

**Request Body:** `AgentErrorV1`

**Response:** `204 No Content`

#### `POST /api/v1/client/agents/{id}/shutdown`

Notify server of agent shutdown.

**Parameters:**

- `id: int` - Agent ID

**Response:** `204 No Content`

### Attack Management

#### `GET /api/v1/client/attacks/{id}`

Retrieve attack configuration by ID.

**Parameters:**

- `id: int` - Attack ID

**Response:** `AttackResponseV1`

#### `GET /api/v1/client/attacks/{id}/hashlist`

Download hash list for the specified attack.

**Parameters:**

- `id: int` - Attack ID

**Response:** Binary hash list file

### Task Management

#### `GET /api/v1/client/tasks/new`

Request a new task assignment.

**Response:** `TaskResponseV1` or `204 No Content` if no tasks available

#### `GET /api/v1/client/tasks/{id}`

Retrieve task details by ID.

**Parameters:**

- `id: int` - Task ID

**Response:** `TaskResponseV1`

#### `POST /api/v1/client/tasks/{id}/accept_task`

Accept an assigned task.

**Parameters:**

- `id: int` - Task ID

**Response:** `204 No Content`

#### `POST /api/v1/client/tasks/{id}/get_zap`

Request zap list (newly cracked hashes) for task.

**Parameters:**

- `id: int` - Task ID

**Response:** Binary zap list file or `204 No Content`

#### `POST /api/v1/client/tasks/{id}/submit_crack`

Submit cracked hash results.

**Parameters:**

- `id: int` - Task ID

**Request Body:** `CrackResultSubmissionV1`

**Response:** `204 No Content`

#### `POST /api/v1/client/tasks/{id}/submit_status`

Submit task status and progress updates.

**Parameters:**

- `id: int` - Task ID

**Request Body:** `TaskStatusUpdateV1`

**Response:** `204 No Content`

#### `POST /api/v1/client/tasks/{id}/abandon_task`

Abandon a task (mark as failed/incomplete).

**Parameters:**

- `id: int` - Task ID

**Response:** `204 No Content`

### Cracker Management

#### `GET /api/v1/client/crackers`

List available cracker binaries and versions.

**Response:** `CrackerListResponseV1`

#### `GET /api/v1/client/crackers/{id}`

Download cracker binary by ID.

**Parameters:**

- `id: int` - Cracker ID

**Response:** Binary cracker file

## Schema Objects

### Agent Schemas

::: app.schemas.agent.AdvancedAgentConfiguration
options:
show_root_heading: true
show_source: false

::: app.schemas.agent.AgentBenchmark
options:
show_root_heading: true
show_source: false

::: app.schemas.agent.AgentErrorV1
options:
show_root_heading: true
show_source: false

::: app.schemas.agent.AgentResponseV1
options:
show_root_heading: true
show_source: false

::: app.schemas.agent.AgentUpdateV1
options:
show_root_heading: true
show_source: false

::: app.schemas.agent.AgentHeartbeatRequest
options:
show_root_heading: true
show_source: false

### Task Schemas

::: app.schemas.task.HashcatResult
options:
show_root_heading: true
show_source: false

::: app.schemas.task.TaskOutV1
options:
show_root_heading: true
show_source: false

::: app.schemas.task.TaskProgressUpdate
options:
show_root_heading: true
show_source: false

::: app.schemas.task.TaskStatusUpdate
options:
show_root_heading: true
show_source: false

### Attack Schemas

::: app.schemas.attack.AttackOutV1
options:
show_root_heading: true
show_source: false

### Error Schemas

::: app.schemas.error.ErrorObject
options:
show_root_heading: true
show_source: false

## Error Handling

The Agent API follows the legacy error format defined in `contracts/v1_api_swagger.json`. All errors return JSON with an `error` field:

```json
{
  "error": "Error message description"
}
```

Common HTTP status codes:

- `200` - Success
- `204` - Success (No Content)
- `401` - Unauthorized (invalid or missing token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found (agent, task, or attack not found)
- `422` - Validation Error (invalid request data)
- `500` - Internal Server Error

## Rate Limiting

Agent API endpoints are subject to rate limiting to prevent abuse. Agents should implement exponential backoff when receiving `429 Too Many Requests` responses.

## Compatibility

This API maintains strict backward compatibility with the legacy Ruby-on-Rails CipherSwarm implementation. Breaking changes are prohibited. All new features requiring API changes will be implemented in Agent API v2 (planned for future release).
