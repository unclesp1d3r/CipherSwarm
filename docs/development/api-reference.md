# API Reference

This document provides detailed specifications for all CipherSwarm APIs.

## API Versioning

CipherSwarm provides three distinct APIs:

1. **Agent API** (`/api/v1/client/*`)

    - Used by distributed agents
    - OpenAPI 3.0.1 specification
    - Bearer token authentication

2. **Web UI API** (`/api/v1/web/*`)

    - Powers the SvelteKit-based interface
    - Session-based authentication
    - Real-time updates

3. **TUI API** (`/api/v1/tui/*`)
    - Command-line interface
    - API key authentication
    - Batch operations

## Agent API

### Authentication

```http
POST /api/v1/client/auth/register
Content-Type: application/json

{
    "name": "agent1",
    "capabilities": {
        "gpus": [
            {
                "id": 0,
                "name": "NVIDIA GeForce RTX 3080",
                "memory": 10240
            }
        ],
        "cpu_cores": 16,
        "memory": 32768
    }
}

Response:
{
    "agent_id": "550e8400-e29b-41d4-a716-446655440000",
    "token": "csa_550e8400-e29b-41d4-a716-446655440000_abcdef123456"
}
```

### Agent Management

#### Heartbeat

```http
POST /api/v1/client/agents/heartbeat
Authorization: Bearer csa_550e8400-e29b-41d4-a716-446655440000_abcdef123456
Content-Type: application/json

{
    "status": "active",
    "metrics": {
        "cpu_usage": 45.2,
        "memory_usage": 8192,
        "gpu_temperatures": [75.5],
        "gpu_utilizations": [92.3]
    }
}

Response:
{
    "command": "continue",
    "next_heartbeat": 60
}
```

#### Update Status

```http
PUT /api/v1/client/agents/status
Authorization: Bearer csa_550e8400-e29b-41d4-a716-446655440000_abcdef123456
Content-Type: application/json

{
    "status": "error",
    "error": "GPU thermal throttling detected"
}

Response:
{
    "acknowledged": true
}
```

### Task Management

#### Get Task

```http
GET /api/v1/client/tasks/next
Authorization: Bearer csa_550e8400-e29b-41d4-a716-446655440000_abcdef123456

Response:
{
    "task_id": "123e4567-e89b-12d3-a456-426614174000",
    "attack_id": "987fcdeb-51d3-12d3-a456-426614174000",
    "config": {
        "type": "dictionary",
        "wordlist": "rockyou.txt",
        "rules": "best64.rule",
        "hash_type": 0
    },
    "resources": {
        "wordlist_url": "https://storage.example.com/wordlists/rockyou.txt",
        "rules_url": "https://storage.example.com/rules/best64.rule"
    },
    "keyspace": {
        "start": 0,
        "end": 1000000
    }
}
```

#### Update Progress

```http
POST /api/v1/client/tasks/123e4567-e89b-12d3-a456-426614174000/progress
Authorization: Bearer csa_550e8400-e29b-41d4-a716-446655440000_abcdef123456
Content-Type: application/json

{
    "progress": 45.5,
    "speed": 1234567,
    "eta": 3600,
    "found": [
        {
            "hash": "5f4dcc3b5aa765d61d8327deb882cf99",
            "plain": "password123"
        }
    ]
}

Response:
{
    "command": "continue"
}
```

#### Complete Task

```http
POST /api/v1/client/tasks/123e4567-e89b-12d3-a456-426614174000/complete
Authorization: Bearer csa_550e8400-e29b-41d4-a716-446655440000_abcdef123456
Content-Type: application/json

{
    "status": "completed",
    "stats": {
        "duration": 3600,
        "speed": 1234567,
        "found_count": 150
    },
    "found": [
        {
            "hash": "5f4dcc3b5aa765d61d8327deb882cf99",
            "plain": "password123"
        }
    ]
}

Response:
{
    "acknowledged": true
}
```

## Web UI API

### Authentication

#### Login

```http
POST /api/v1/web/auth/login
Content-Type: application/json

{
    "username": "admin",
    "password": "secure_password"
}

Response:
Set-Cookie: session=abc123...
{
    "user": {
        "id": "123",
        "username": "admin",
        "role": "administrator"
    }
}
```

#### Refresh Token

```http
POST /api/v1/web/auth/refresh
Cookie: session=abc123...

Response:
Set-Cookie: session=def456...
{
    "acknowledged": true
}
```

### Campaign Management

#### Create Campaign

```http
POST /api/v1/web/campaigns
Content-Type: application/json
Cookie: session=abc123...

{
    "name": "Password Audit 2024",
    "description": "Annual password audit",
    "priority": "high",
    "tags": ["audit", "compliance"]
}

Response:
{
    "campaign_id": "123e4567-e89b-12d3-a456-426614174000",
    "name": "Password Audit 2024",
    "status": "created"
}
```

#### List Campaigns

```http
GET /api/v1/web/campaigns?status=active&page=1&per_page=10
Cookie: session=abc123...

Response:
{
    "items": [
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "name": "Password Audit 2024",
            "status": "active",
            "progress": 45.5,
            "created_at": "2024-03-15T10:00:00Z"
        }
    ],
    "total": 15,
    "page": 1,
    "per_page": 10
}
```

### Attack Management

#### Create Attack

```http
POST /api/v1/web/campaigns/123e4567-e89b-12d3-a456-426614174000/attacks
Content-Type: application/json
Cookie: session=abc123...

{
    "name": "Common Passwords",
    "type": "dictionary",
    "config": {
        "wordlist": "rockyou.txt",
        "rules": "best64.rule",
        "hash_type": 0
    },
    "resources": {
        "wordlist_id": "abc123",
        "rules_id": "def456"
    }
}

Response:
{
    "attack_id": "987fcdeb-51d3-12d3-a456-426614174000",
    "status": "created"
}
```

#### Monitor Attack

```http
GET /api/v1/web/attacks/987fcdeb-51d3-12d3-a456-426614174000
Cookie: session=abc123...

Response:
{
    "id": "987fcdeb-51d3-12d3-a456-426614174000",
    "name": "Common Passwords",
    "status": "running",
    "progress": 45.5,
    "stats": {
        "speed": 1234567,
        "found": 150,
        "eta": 3600
    },
    "agents": [
        {
            "id": "550e8400-e29b-41d3-a716-446655440000",
            "name": "agent1",
            "progress": 45.5,
            "speed": 1234567
        }
    ]
}
```

### Resource Management

#### Upload Resource

```http
POST /api/v1/web/resources
Content-Type: multipart/form-data
Cookie: session=abc123...

Form Data:
- file: (binary)
- type: "wordlist"
- name: "custom.txt"
- description: "Custom wordlist"

Response:
{
    "resource_id": "abc123",
    "name": "custom.txt",
    "type": "wordlist",
    "size": 1048576,
    "checksum": "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8"
}
```

#### List Resources

```http
GET /api/v1/web/resources?type=wordlist&page=1&per_page=10
Cookie: session=abc123...

Response:
{
    "items": [
        {
            "id": "abc123",
            "name": "custom.txt",
            "type": "wordlist",
            "size": 1048576,
            "created_at": "2024-03-15T10:00:00Z"
        }
    ],
    "total": 25,
    "page": 1,
    "per_page": 10
}
```

## TUI API

### Authentication

#### Generate API Key

```http
POST /api/v1/tui/auth/keys
Content-Type: application/json
Authorization: Bearer cst_user123_xyz789

{
    "name": "cli-key",
    "expires_in": 2592000,  # 30 days
    "scopes": ["read", "write"]
}

Response:
{
    "key_id": "key123",
    "api_key": "cst_user123_abc456",
    "expires_at": "2024-04-15T10:00:00Z"
}
```

### Campaign Operations

#### List Campaigns

```http
GET /api/v1/tui/campaigns
Authorization: Bearer cst_user123_xyz789

Response:
{
    "campaigns": [
        {
            "id": "123e4567-e89b-12d3-a456-426614174000",
            "name": "Password Audit 2024",
            "status": "active",
            "progress": 45.5
        }
    ]
}
```

#### Batch Operations

```http
POST /api/v1/tui/campaigns/batch
Content-Type: application/json
Authorization: Bearer cst_user123_xyz789

{
    "operation": "pause",
    "campaign_ids": [
        "123e4567-e89b-12d3-a456-426614174000",
        "987fcdeb-51d3-12d3-a456-426614174000"
    ]
}

Response:
{
    "results": [
        {
            "campaign_id": "123e4567-e89b-12d3-a456-426614174000",
            "status": "success"
        },
        {
            "campaign_id": "987fcdeb-51d3-12d3-a456-426614174000",
            "status": "success"
        }
    ]
}
```

### Monitoring

#### System Status

```http
GET /api/v1/tui/status
Authorization: Bearer cst_user123_xyz789

Response:
{
    "agents": {
        "total": 10,
        "active": 8,
        "error": 1,
        "stopped": 1
    },
    "tasks": {
        "running": 15,
        "queued": 25,
        "completed": 150
    },
    "resources": {
        "cpu_usage": 45.2,
        "memory_usage": 8192,
        "storage_usage": 102400
    }
}
```

#### Performance Metrics

```http
GET /api/v1/tui/metrics?period=1h
Authorization: Bearer cst_user123_xyz789

Response:
{
    "metrics": {
        "timestamps": [...],
        "speed": [...],
        "found": [...],
        "agents": [...]
    }
}
```

## Error Responses

All APIs use consistent error response formats:

```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
    "error": {
        "code": "validation_error",
        "message": "Invalid request parameters",
        "details": {
            "field": "name",
            "reason": "required"
        }
    }
}
```

Common error codes:

-   `validation_error`: Invalid request parameters
-   `authentication_error`: Invalid or missing credentials
-   `authorization_error`: Insufficient permissions
-   `not_found`: Resource not found
-   `rate_limit_exceeded`: Too many requests
-   `internal_error`: Server error

## Rate Limiting

All APIs implement rate limiting:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1523456789

{
    "error": {
        "code": "rate_limit_exceeded",
        "message": "Too many requests",
        "details": {
            "retry_after": 60
        }
    }
}
```

## Webhooks

The system supports webhooks for event notifications:

```http
POST https://your-webhook-url
Content-Type: application/json
X-CipherSwarm-Signature: sha256=...

{
    "event": "task.completed",
    "timestamp": "2024-03-15T10:00:00Z",
    "data": {
        "task_id": "123e4567-e89b-12d3-a456-426614174000",
        "status": "completed",
        "found_count": 150
    }
}
```

Available events:

-   `task.created`
-   `task.started`
-   `task.completed`
-   `task.failed`
-   `agent.registered`
-   `agent.error`
-   `campaign.completed`

For more information:

-   [Authentication Guide](../development/authentication.md)
-   [Security Guide](../development/security.md)
-   [Performance Guide](../development/performance.md)
