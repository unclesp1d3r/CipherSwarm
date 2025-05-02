# API Documentation

CipherSwarm provides three distinct API interfaces:

1. Agent API (`/api/v1/client/*`)
2. Web UI API (`/api/v1/web/*`)
3. TUI API (`/api/v1/tui/*`)

## Agent API

The Agent API follows the OpenAPI 3.0.1 specification defined in `swagger.json`.

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

### Task Management

```http
GET /api/v1/client/tasks/next
Authorization: Bearer csa_550e8400-e29b-41d4-a716-446655440000_abcdef123456

Response:
{
    "task_id": "123e4567-e89b-12d3-a456-426614174000",
    "attack_id": "987fcdeb-51d2-11e9-8647-d663bd873d93",
    "type": "dictionary",
    "config": {
        "wordlist_url": "https://storage.example.com/wordlists/rockyou.txt",
        "rules_url": "https://storage.example.com/rules/best64.rule",
        "hash_type": 0
    }
}
```

### Progress Reporting

```http
POST /api/v1/client/tasks/{task_id}/progress
Authorization: Bearer csa_550e8400-e29b-41d4-a716-446655440000_abcdef123456
Content-Type: application/json

{
    "progress": 45.5,
    "speed": 1234567,
    "recovered": 100,
    "total": 1000
}
```

### Result Submission

```http
POST /api/v1/client/tasks/{task_id}/results
Authorization: Bearer csa_550e8400-e29b-41d4-a716-446655440000_abcdef123456
Content-Type: application/json

{
    "results": [
        {
            "hash": "5f4dcc3b5aa765d61d8327deb882cf99",
            "plain": "password",
            "time": 123.45
        }
    ],
    "stats": {
        "duration": 3600,
        "speed": 1234567,
        "rejected": 0
    }
}
```

## Web UI API

The Web UI API powers the HTMX-based interface.

### Authentication

```http
POST /api/v1/web/auth/login
Content-Type: application/json

{
    "username": "admin",
    "password": "secure_password"
}

Response:
{
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "token_type": "bearer"
}
```

### Attack Management

```http
POST /api/v1/web/attacks
Content-Type: application/json
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...

{
    "name": "Test Attack",
    "type": "dictionary",
    "config": {
        "wordlist": "rockyou.txt",
        "rules": "best64.rule",
        "hash_type": 0
    }
}

Response:
{
    "attack_id": "987fcdeb-51d2-11e9-8647-d663bd873d93",
    "status": "created"
}
```

### Resource Management

```http
POST /api/v1/web/resources/wordlists
Content-Type: multipart/form-data
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...

file: <wordlist_file>
name: rockyou.txt
description: Common password list

Response:
{
    "resource_id": "abc123def456",
    "name": "rockyou.txt",
    "size": 139921497,
    "md5": "3f3a1c2d5e6b7890"
}
```

### Real-time Updates

```http
GET /api/v1/web/ws
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
Upgrade: websocket

# WebSocket Messages
-> {"type": "subscribe", "channel": "attack.123.status"}
<- {"type": "attack_update", "attack_id": "123", "progress": 45.5}
```

## TUI API

The TUI API provides a command-line interface.

### Authentication

```http
POST /api/v1/tui/auth/token
Content-Type: application/json

{
    "api_key": "cst_user123_abcdef123456"
}

Response:
{
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "token_type": "bearer"
}
```

### Batch Operations

```http
POST /api/v1/tui/batch/attacks
Content-Type: application/json
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...

{
    "attacks": [
        {
            "name": "Attack 1",
            "type": "dictionary",
            "config": {...}
        },
        {
            "name": "Attack 2",
            "type": "mask",
            "config": {...}
        }
    ]
}

Response:
{
    "created": [
        {"id": "123", "status": "created"},
        {"id": "456", "status": "created"}
    ]
}
```

## Common Response Formats

### Error Responses

```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
    "detail": {
        "code": "VALIDATION_ERROR",
        "message": "Invalid request parameters",
        "errors": [
            {
                "field": "name",
                "error": "Field required"
            }
        ]
    }
}
```

### Pagination

```http
GET /api/v1/web/attacks?page=2&per_page=10

Response:
{
    "items": [...],
    "total": 45,
    "page": 2,
    "per_page": 10,
    "pages": 5
}
```

## API Versioning

The API is versioned through the URL path:

-   `/api/v1/*` - Current stable version
-   `/api/v2/*` - Future version (when available)

Changes to the API are handled according to semantic versioning:

1. PATCH version - Backward compatible bug fixes
2. MINOR version - New functionality in a backward compatible manner
3. MAJOR version - Incompatible API changes

## Rate Limiting

All API endpoints are rate limited:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1618884730

{
    "detail": {
        "code": "RATE_LIMIT_EXCEEDED",
        "message": "Too many requests",
        "retry_after": 60
    }
}
```

## API Security

1. **Authentication**

    - JWT tokens for Web/TUI API
    - Agent-specific tokens for Agent API
    - Token rotation and expiration

2. **Authorization**

    - Role-based access control
    - Resource ownership validation
    - Scope-based permissions

3. **Input Validation**
    - Request schema validation
    - Data sanitization
    - File type verification

For more information, see:

-   [OpenAPI Specification](https://github.com/yourusername/cipherswarm/blob/main/swagger.json)
-   [Authentication Guide](../development/authentication.md)
-   [API Security](../development/security.md)
