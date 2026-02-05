# CipherSwarm Agent API Complete Reference

**Version**: 1.3 **Base URL**: `https://cipherswarm.com/api/v1/client` **Authentication**: Bearer Token **Content-Type**: `application/json`

---

## Overview

The CipherSwarm Agent API enables distributed hash-cracking agents to communicate with the CipherSwarm server. Agents authenticate using bearer tokens, receive task assignments, report progress, and submit cracked hashes.

### API Workflow

```
Agent Startup:
  1. GET /authenticate → Verify token validity
  2. GET /configuration → Get agent settings
  3. PUT /agents/{id} → Register device info
  4. POST /agents/{id}/submit_benchmark → Submit benchmarks

Task Loop:
  5. GET /tasks/new → Request task
  6. POST /tasks/{id}/accept_task → Accept task
  7. GET /attacks/{id} → Get attack parameters
  8. GET /attacks/{id}/hash_list → Download hashes

Work Loop:
  9. POST /tasks/{id}/submit_status → Report progress
  10. POST /tasks/{id}/submit_crack → Submit cracks
  11. GET /tasks/{id}/get_zaps → Get completed hashes

Completion:
  12. POST /tasks/{id}/exhausted → Mark complete
  -or-
  12. POST /tasks/{id}/abandon → Abandon task

Maintenance:
  POST /agents/{id}/heartbeat → Keep alive
  POST /agents/{id}/submit_error → Report errors
  POST /agents/{id}/shutdown → Graceful shutdown
```

---

## Authentication

All API requests require a Bearer token in the Authorization header.

```http
Authorization: Bearer <agent_token>
```

### Token Format

- 24-character alphanumeric string
- Generated when agent is created in web UI
- Stored in `agents.token` column
- Revokable by admin

### Authentication Errors

| Status | Meaning                            |
| ------ | ---------------------------------- |
| 401    | Invalid or missing token           |
| 403    | Agent is stopped or in error state |

---

## Endpoints

### Client Authentication

#### GET /authenticate

Verify agent token and retrieve agent ID.

**Response** (200 OK):

```json
{
  "authenticated": true,
  "agent_id": 42
}
```

**Response** (401 Unauthorized):

```json
{
  "error": "Invalid token"
}
```

---

#### GET /configuration

Get agent configuration settings.

**Response** (200 OK):

```json
{
  "config": {
    "agent_update_interval": 60,
    "use_native_hashcat": false,
    "backend_device": null,
    "opencl_devices": null,
    "enable_additional_hash_types": false
  },
  "api_version": 1
}
```

---

### Agent Management

#### GET /agents/{id}

Get agent details.

**Parameters**:

| Name | Type    | Required | Description |
| ---- | ------- | -------- | ----------- |
| id   | integer | Yes      | Agent ID    |

**Response** (200 OK):

```json
{
  "id": 42,
  "host_name": "cracker-01",
  "client_signature": "CipherSwarmAgent/1.0",
  "state": "active",
  "operating_system": "Linux 5.15.0",
  "devices": [
    "NVIDIA RTX 4090",
    "NVIDIA RTX 4090"
  ],
  "current_activity": "cracking",
  "advanced_configuration": {
    "agent_update_interval": 60,
    "use_native_hashcat": false,
    "backend_device": "1,2",
    "opencl_devices": null,
    "enable_additional_hash_types": false
  }
}
```

**Agent States**:

| State   | Description                                |
| ------- | ------------------------------------------ |
| pending | Agent needs to complete setup (benchmarks) |
| active  | Agent is ready to accept tasks             |
| stopped | Agent has been stopped by administrator    |
| error   | Agent encountered an error                 |

---

#### PUT /agents/{id}

Update agent information (typically on startup).

**Request Body**:

```json
{
  "id": 42,
  "host_name": "cracker-01",
  "client_signature": "CipherSwarmAgent/1.0",
  "operating_system": "Linux 5.15.0",
  "devices": [
    "NVIDIA RTX 4090",
    "NVIDIA RTX 4090"
  ]
}
```

**Response** (200 OK): Returns updated Agent object.

---

#### POST /agents/{id}/heartbeat

Send heartbeat to keep agent alive. Should be called at regular intervals (default: every 60 seconds).

**Request Body** (optional):

```json
{
  "activity": "cracking"
}
```

**Activity Values**:

| Activity     | Description                              |
| ------------ | ---------------------------------------- |
| starting     | Agent is starting up                     |
| benchmarking | Running hashcat benchmarks               |
| updating     | Updating hashcat or agent                |
| downloading  | Downloading resources (wordlists, rules) |
| waiting      | Idle, waiting for tasks                  |
| cracking     | Actively working on a task               |
| stopping     | Shutting down                            |

**Response** (204 No Content): Heartbeat accepted, agent is in good state.

**Response** (200 OK): Server has feedback for agent:

```json
{
  "state": "pending"
}
```

Possible states in response:

- `pending` - Agent needs to re-run benchmarks
- `stopped` - Agent should stop and shutdown
- `error` - Agent has been marked as errored

---

#### POST /agents/{id}/submit_benchmark

Submit hashcat benchmark results.

**Request Body**:

```json
{
  "hashcat_benchmarks": [
    {
      "hash_type": 0,
      "runtime": 5000,
      "hash_speed": 15000000000.0,
      "device": 1
    },
    {
      "hash_type": 1000,
      "runtime": 5000,
      "hash_speed": 8500000000.0,
      "device": 1
    }
  ]
}
```

**Response** (204 No Content): Benchmarks accepted.

**Response** (400 Bad Request):

```json
{
  "error": "Invalid benchmark data"
}
```

---

#### POST /agents/{id}/submit_error

Report an error to the server.

**Request Body**:

```json
{
  "message": "GPU temperature exceeded threshold",
  "severity": "major",
  "agent_id": 42,
  "task_id": 123,
  "metadata": {
    "error_date": "2025-01-15T10:30:00Z",
    "other": {
      "gpu_temp": 95,
      "gpu_id": 1
    }
  }
}
```

**Severity Levels**:

| Level    | Description               | Action         |
| -------- | ------------------------- | -------------- |
| info     | Informational message     | None           |
| warning  | Non-critical, anticipated | None           |
| minor    | Should investigate        | Task continues |
| major    | Requires attention        | Check task     |
| critical | Immediate action needed   | Stop task      |
| fatal    | Agent cannot continue     | Do not retry   |

**Response** (204 No Content): Error logged.

---

#### POST /agents/{id}/shutdown

Mark agent as offline and release any assigned tasks.

**Response** (204 No Content): Agent marked as shutdown.

---

### Task Management

#### GET /tasks/new

Request a new task assignment.

**Response** (200 OK): Task available:

```json
{
  "id": 123,
  "attack_id": 456,
  "start_date": "2025-01-15T10:00:00Z",
  "status": "pending",
  "skip": 0,
  "limit": 10000000
}
```

**Response** (204 No Content): No tasks available.

---

#### GET /tasks/{id}

Get task details.

**Response** (200 OK):

```json
{
  "id": 123,
  "attack_id": 456,
  "start_date": "2025-01-15T10:00:00Z",
  "status": "running",
  "skip": 0,
  "limit": 10000000
}
```

**Task Status Values**:

| Status    | Description                       |
| --------- | --------------------------------- |
| pending   | Task created, not yet accepted    |
| running   | Agent is working on task          |
| completed | All hashes cracked                |
| exhausted | Keyspace exhausted, task finished |
| failed    | Task failed with errors           |
| paused    | Task paused by server             |

---

#### POST /tasks/{id}/accept_task

Accept an offered task and start working.

**Response** (204 No Content): Task accepted.

**Response** (404 Not Found):

```json
{
  "error": "Task not found for agent"
}
```

**Response** (422 Unprocessable Entity):

```json
{
  "error": "Task already completed"
}
```

---

#### POST /tasks/{id}/submit_status

Submit task progress update (call regularly during cracking).

**Request Body**:

```json
{
  "original_line": "STATUS\t5\tcracking\t...",
  "time": "2025-01-15T10:15:00Z",
  "session": "task_123",
  "status": 5,
  "target": "hashlist.txt",
  "progress": [
    5000000,
    10000000
  ],
  "restore_point": 5000000,
  "recovered_hashes": [
    42,
    100
  ],
  "recovered_salts": [
    1,
    1
  ],
  "rejected": 0,
  "time_start": "2025-01-15T10:00:00Z",
  "estimated_stop": "2025-01-15T10:30:00Z",
  "hashcat_guess": {
    "guess_base": "rockyou.txt",
    "guess_base_count": 14344391,
    "guess_base_offset": 7000000,
    "guess_base_percentage": 48.8,
    "guess_mod": "",
    "guess_mod_count": 0,
    "guess_mod_offset": 0,
    "guess_mod_percentage": 0.0,
    "guess_mode": 0
  },
  "device_statuses": [
    {
      "device_id": 1,
      "device_name": "NVIDIA RTX 4090",
      "device_type": "GPU",
      "speed": 15000000000,
      "utilization": 98,
      "temperature": 72
    }
  ]
}
```

**Response** (204 No Content): Status received.

**Response** (202 Accepted): Status received but data is stale (submit more frequently).

**Response** (410 Gone): Task has been paused - stop work and wait.

**Response** (422 Unprocessable Entity):

```json
{
  "error": "Malformed status data"
}
```

---

#### POST /tasks/{id}/submit_crack

Submit a cracked hash.

**Request Body**:

```json
{
  "timestamp": "2025-01-15T10:20:00Z",
  "hash": "5f4dcc3b5aa765d61d8327deb882cf99",
  "plain_text": "password"
}
```

**Response** (200 OK): Crack accepted, more hashes remain.

**Response** (204 No Content): Crack accepted, all hashes in list are now cracked.

**Response** (404 Not Found):

```json
{
  "error": "Hash value not found in list"
}
```

---

#### POST /tasks/{id}/exhausted

Mark task as exhausted (keyspace fully searched).

**Response** (204 No Content): Task marked as exhausted.

---

#### POST /tasks/{id}/abandon

Abandon a task (agent cannot complete it).

**Response** (200 OK):

```json
{
  "success": true,
  "state": "pending"
}
```

**Response** (422 Unprocessable Entity):

```json
{
  "error": "Task already completed",
  "details": [
    "Cannot abandon completed tasks"
  ]
}
```

> [!WARNING]
> Abandoning a task may trigger rebalancing of all tasks for that attack.

---

#### GET /tasks/{id}/get_zaps

Get hashes that have been cracked by other agents (for runtime removal).

**Response** (200 OK): Returns plain text list of cracked hashes:

```
5f4dcc3b5aa765d61d8327deb882cf99
e99a18c428cb38d5f260853678922e03
```

Add these to hashcat's `--potfile-path` or remove from working hash list.

---

### Attack Information

#### GET /attacks/{id}

Get attack details and hashcat parameters.

**Response** (200 OK):

```json
{
  "id": 456,
  "attack_mode": "dictionary",
  "attack_mode_hashcat": 0,
  "mask": null,
  "increment_mode": false,
  "increment_minimum": 0,
  "increment_maximum": 0,
  "optimized": true,
  "slow_candidate_generators": false,
  "workload_profile": 3,
  "disable_markov": false,
  "classic_markov": false,
  "markov_threshold": 0,
  "left_rule": null,
  "right_rule": null,
  "custom_charset_1": null,
  "custom_charset_2": null,
  "custom_charset_3": null,
  "custom_charset_4": null,
  "hash_list_id": 789,
  "hash_mode": 1000,
  "hash_list_url": "https://cipherswarm.com/rails/active_storage/blobs/...",
  "hash_list_checksum": "d41d8cd98f00b204e9800998ecf8427e",
  "url": "/api/v1/client/attacks/456",
  "word_list": {
    "id": 1,
    "download_url": "https://cipherswarm.com/rails/active_storage/blobs/...",
    "checksum": "abc123...",
    "file_name": "rockyou.txt"
  },
  "rule_list": null,
  "mask_list": null
}
```

**Attack Modes**:

| Mode              | Name                    | Hashcat Mode |
| ----------------- | ----------------------- | ------------ |
| dictionary        | Dictionary attack       | 0            |
| mask              | Mask/brute-force attack | 3            |
| hybrid_dictionary | Dictionary + Mask       | 6            |
| hybrid_mask       | Mask + Dictionary       | 7            |

---

#### GET /attacks/{id}/hash_list

Download the hash list file for an attack.

**Response** (200 OK): Returns plain text hash list:

```
5f4dcc3b5aa765d61d8327deb882cf99
e99a18c428cb38d5f260853678922e03
098f6bcd4621d373cade4e832627b4f6
```

---

## Error Handling

### Standard Error Response

All errors return JSON with an `error` field:

```json
{
  "error": "Description of the error"
}
```

### HTTP Status Codes

| Code | Meaning                                 |
| ---- | --------------------------------------- |
| 200  | Success with response body              |
| 202  | Accepted but stale data                 |
| 204  | Success with no content                 |
| 400  | Bad request (invalid parameters)        |
| 401  | Unauthorized (invalid token)            |
| 404  | Resource not found                      |
| 410  | Resource gone (task paused)             |
| 422  | Unprocessable entity (validation error) |
| 500  | Internal server error                   |

---

## Rate Limiting

The API does not currently enforce rate limits, but agents should:

- Send heartbeats every 60 seconds (configurable via `agent_update_interval`)
- Submit status updates every 5-10 seconds during active cracking
- Submit cracks immediately as they are found

---

## Code Examples

### Python Example

```python
import requests


class CipherSwarmClient:
    def __init__(self, base_url, token):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers["Authorization"] = f"Bearer {token}"
        self.session.headers["Content-Type"] = "application/json"

    def authenticate(self):
        resp = self.session.get(f"{self.base_url}/authenticate")
        resp.raise_for_status()
        return resp.json()

    def get_new_task(self):
        resp = self.session.get(f"{self.base_url}/tasks/new")
        if resp.status_code == 204:
            return None
        resp.raise_for_status()
        return resp.json()

    def accept_task(self, task_id):
        resp = self.session.post(f"{self.base_url}/tasks/{task_id}/accept_task")
        resp.raise_for_status()

    def submit_crack(self, task_id, hash_value, plain_text):
        resp = self.session.post(
            f"{self.base_url}/tasks/{task_id}/submit_crack",
            json={
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "hash": hash_value,
                "plain_text": plain_text,
            },
        )
        resp.raise_for_status()
        return resp.status_code == 200  # True if more hashes remain


# Usage
client = CipherSwarmClient("https://cipherswarm.com/api/v1/client", "YOUR_TOKEN")
auth = client.authenticate()
print(f"Authenticated as agent {auth['agent_id']}")
```

### cURL Example

```bash
# Authenticate
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://cipherswarm.com/api/v1/client/authenticate

# Get new task
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://cipherswarm.com/api/v1/client/tasks/new

# Accept task
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  https://cipherswarm.com/api/v1/client/tasks/123/accept_task

# Submit crack
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"timestamp":"2025-01-15T10:20:00Z","hash":"5f4dcc3b...","plain_text":"password"}' \
  https://cipherswarm.com/api/v1/client/tasks/123/submit_crack
```

---

## Changelog

### Version 1.3 (Current)

- Added `current_activity` field to Agent
- Added `activity` parameter to heartbeat endpoint
- Improved error responses with structured JSON

### Version 1.2

- Added `get_zaps` endpoint for runtime hash removal
- Added task preemption support (410 response on submit_status)

### Version 1.1

- Added `advanced_configuration` to Agent
- Added benchmark submission endpoint

### Version 1.0

- Initial release
