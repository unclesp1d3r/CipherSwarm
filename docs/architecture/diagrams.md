# CipherSwarm Architecture Diagrams

This document contains Mermaid diagrams illustrating the CipherSwarm system architecture.

---

## System Architecture Overview

```mermaid
graph TB
    subgraph "Web Clients"
        Browser[Web Browser]
        Admin[Admin Dashboard]
    end

    subgraph "CipherSwarm Server"
        subgraph "Rails Application"
            WebUI[Web UI Controllers]
            API[Agent API v1]
            Jobs[Sidekiq Workers]
            Cable[Action Cable]
        end

        subgraph "Data Layer"
            PG[(PostgreSQL)]
            Redis[(Redis)]
            Storage[Active Storage]
        end
    end

    subgraph "Distributed Agents"
        Agent1[Agent 1<br/>GPU Cluster]
        Agent2[Agent 2<br/>CPU Farm]
        Agent3[Agent N<br/>...]
    end

    subgraph "External Storage"
        S3[AWS S3<br/>Production]
        Disk[Local Disk<br/>Development]
    end

    Browser --> WebUI
    Browser --> Cable
    Admin --> WebUI

    WebUI --> PG
    API --> PG
    Jobs --> PG
    Jobs --> Redis
    Cable --> Redis

    Storage --> S3
    Storage --> Disk

    Agent1 --> API
    Agent2 --> API
    Agent3 --> API

    WebUI --> Jobs
    API --> Jobs
```

---

## Domain Model

```mermaid
erDiagram
    PROJECT ||--o{ CAMPAIGN : contains
    PROJECT ||--o{ PROJECT_USER : has
    PROJECT ||--o{ AGENT : "assigned to"
    USER ||--o{ PROJECT_USER : belongs
    USER ||--o{ CAMPAIGN : creates
    USER ||--o{ ATTACK : creates

    CAMPAIGN ||--|| HASH_LIST : targets
    CAMPAIGN ||--o{ ATTACK : contains

    HASH_LIST ||--|| HASH_TYPE : "of type"
    HASH_LIST ||--o{ HASH_ITEM : contains

    ATTACK ||--o{ TASK : "divided into"
    ATTACK }o--|| WORD_LIST : uses
    ATTACK }o--|| RULE_LIST : uses
    ATTACK }o--|| MASK_LIST : uses

    TASK ||--|| AGENT : "assigned to"
    TASK ||--o{ HASHCAT_STATUS : tracks
    TASK ||--o{ AGENT_ERROR : logs

    AGENT ||--o{ HASHCAT_BENCHMARK : has

    PROJECT {
        bigint id PK
        string name
        text description
        timestamps created_at
    }

    CAMPAIGN {
        bigint id PK
        string name
        integer priority
        string state
        bigint project_id FK
        bigint hash_list_id FK
        bigint creator_id FK
    }

    ATTACK {
        bigint id PK
        string name
        string attack_mode
        string state
        bigint complexity_value
        bigint campaign_id FK
        bigint word_list_id FK
        bigint rule_list_id FK
        bigint mask_list_id FK
    }

    TASK {
        bigint id PK
        string state
        bigint skip
        bigint limit
        bigint attack_id FK
        bigint agent_id FK
        datetime start_date
    }

    AGENT {
        bigint id PK
        string host_name
        string token
        string state
        string operating_system
        jsonb devices
        jsonb advanced_configuration
    }

    HASH_LIST {
        bigint id PK
        string name
        bigint hash_type_id FK
        bigint project_id FK
    }

    HASH_ITEM {
        bigint id PK
        string hash_value
        string plain_text
        boolean cracked
        bigint hash_list_id FK
    }
```

---

## State Machine Diagrams

### Agent State Machine

```mermaid
stateDiagram-v2
    [*] --> pending: Agent Created

    pending --> active: activate
    active --> benchmarked: benchmarked
    active --> error: error
    active --> stopped: stop

    benchmarked --> active: "needs rebenchmark"
    benchmarked --> error: error
    benchmarked --> stopped: stop

    error --> pending: reset
    stopped --> pending: restart

    error --> [*]: delete
    stopped --> [*]: delete
```

### Attack State Machine

```mermaid
stateDiagram-v2
    [*] --> pending: Attack Created

    pending --> running: run
    running --> paused: pause
    paused --> running: resume

    running --> completed: complete
    running --> exhausted: exhaust
    running --> failed: fail

    paused --> completed: complete
    paused --> failed: fail

    completed --> [*]
    exhausted --> [*]
    failed --> [*]
```

### Task State Machine

```mermaid
stateDiagram-v2
    [*] --> pending: Task Created

    pending --> running: accept
    running --> paused: pause
    paused --> running: resume

    running --> completed: complete
    running --> exhausted: exhaust
    running --> failed: error

    pending --> failed: cancel
    running --> pending: abandon
    paused --> pending: abandon

    completed --> [*]
    exhausted --> [*]
    failed --> pending: retry
```

---

## Sequence Diagrams

### Agent Task Workflow

```mermaid
sequenceDiagram
    participant A as Agent
    participant API as CipherSwarm API
    participant DB as Database
    participant Jobs as Sidekiq

    Note over A: Agent Startup
    A->>API: GET /authenticate
    API->>DB: Find Agent by Token
    DB-->>API: Agent Record
    API-->>A: { authenticated: true, agent_id: 42 }

    A->>API: GET /configuration
    API-->>A: { config: {...}, api_version: 1 }

    A->>API: PUT /agents/42
    API->>DB: Update Agent Info
    API-->>A: Agent Object

    Note over A: Task Request Loop
    A->>API: GET /tasks/new
    API->>DB: Query Available Attacks
    API->>DB: Create Task for Agent
    API-->>A: { id: 123, attack_id: 456, ... }

    A->>API: POST /tasks/123/accept_task
    API->>DB: Update Task State
    API-->>A: 204 No Content

    A->>API: GET /attacks/456
    API-->>A: Attack Details + Hashcat Params

    A->>API: GET /attacks/456/hash_list
    API-->>A: Hash List File (text/plain)

    Note over A: Cracking Loop
    loop Every 5-10 seconds
        A->>API: POST /tasks/123/submit_status
        API->>DB: Save HashcatStatus
        API->>Jobs: UpdateStatusJob
        API-->>A: 204 No Content
    end

    loop On each crack
        A->>API: POST /tasks/123/submit_crack
        API->>DB: Update HashItem
        API-->>A: 200 OK
    end

    Note over A: Task Completion
    A->>API: POST /tasks/123/exhausted
    API->>DB: Mark Task Exhausted
    API->>Jobs: Check Attack Completion
    API-->>A: 204 No Content
```

### Campaign Creation Flow

```mermaid
sequenceDiagram
    participant U as User
    participant UI as Web UI
    participant C as Controller
    participant M as Models
    participant DB as Database

    U->>UI: Create New Campaign
    UI->>C: GET /campaigns/new
    C->>M: Load Projects, HashLists
    M->>DB: Query Data
    DB-->>M: Results
    C-->>UI: New Campaign Form

    U->>UI: Submit Campaign Form
    UI->>C: POST /campaigns
    C->>M: Campaign.new(params)
    M->>DB: Validate & Save
    DB-->>M: Campaign Created
    M->>M: broadcast_refreshes
    C-->>UI: Redirect to Campaign

    U->>UI: Add Attack to Campaign
    UI->>C: GET /campaigns/1/attacks/new
    C-->>UI: Attack Form

    U->>UI: Submit Attack Form
    UI->>C: POST /campaigns/1/attacks
    C->>M: Attack.new(params)
    M->>M: calculate_complexity
    M->>DB: Save Attack
    DB-->>M: Attack Created
    C-->>UI: Redirect to Attack

    Note over U,DB: Tasks Created When Agent Requests Work
```

### Task Preemption Flow

```mermaid
sequenceDiagram
    participant A1 as Agent (High Priority)
    participant A2 as Agent (Low Priority)
    participant API as CipherSwarm API
    participant TPS as TaskPreemptionService
    participant DB as Database

    Note over A2: Agent 2 working on low priority task
    A2->>API: POST /tasks/456/submit_status
    API-->>A2: 204 OK

    Note over A1: Agent 1 requests high priority task
    A1->>API: GET /tasks/new
    API->>DB: Query Available Tasks
    DB-->>API: No tasks for high priority attack

    API->>TPS: preempt_if_needed(attack)
    TPS->>DB: Find Preemptable Tasks
    Note over TPS: Tasks with lower priority<br/>and >10% progress
    DB-->>TPS: Task 456 (Agent 2's task)

    TPS->>DB: Lock Task 456
    TPS->>DB: Set state=pending, stale=true
    TPS->>DB: Increment preemption_count

    TPS-->>API: Task 456 preempted
    API->>DB: Create Task for Agent 1
    API-->>A1: { id: 789, ... }

    Note over A2: Agent 2's next status update
    A2->>API: POST /tasks/456/submit_status
    API-->>A2: 410 Gone (Task Paused)

    A2->>API: GET /tasks/new
    API-->>A2: New Task (or 204 if none)
```

---

## Component Architecture

```mermaid
graph TB
    subgraph "Presentation Layer"
        Controllers[Controllers]
        Views[Views & ViewComponents]
        Cable[Action Cable Channels]
        Stimulus[Stimulus Controllers]
    end

    subgraph "Business Logic Layer"
        Models[ActiveRecord Models]
        Services[Service Objects]
        Concerns[Model Concerns]
        Jobs[Background Jobs]
    end

    subgraph "Data Access Layer"
        AR[ActiveRecord]
        Redis[Redis Client]
        AS[Active Storage]
    end

    subgraph "External Systems"
        PG[(PostgreSQL)]
        RedisDB[(Redis)]
        S3[(S3/Disk)]
    end

    Controllers --> Models
    Controllers --> Services
    Views --> Models
    Cable --> Models
    Stimulus --> Cable

    Models --> Concerns
    Models --> AR
    Services --> Models
    Jobs --> Models
    Jobs --> Redis

    AR --> PG
    Redis --> RedisDB
    AS --> S3
```

---

## Deployment Architecture

```mermaid
graph TB
    subgraph "Load Balancer"
        LB[NGINX/Traefik]
    end

    subgraph "Application Tier"
        Web1[Puma Web Server 1]
        Web2[Puma Web Server 2]
        Sidekiq1[Sidekiq Worker 1]
        Sidekiq2[Sidekiq Worker 2]
    end

    subgraph "Data Tier"
        PG[(PostgreSQL Primary)]
        PGR[(PostgreSQL Replica)]
        Redis[(Redis)]
    end

    subgraph "Storage Tier"
        S3[AWS S3]
    end

    subgraph "Monitoring"
        Prometheus[Prometheus]
        Grafana[Grafana]
        Logs[Log Aggregator]
    end

    LB --> Web1
    LB --> Web2

    Web1 --> PG
    Web1 --> Redis
    Web1 --> S3
    Web2 --> PG
    Web2 --> Redis
    Web2 --> S3

    Sidekiq1 --> PG
    Sidekiq1 --> Redis
    Sidekiq2 --> PG
    Sidekiq2 --> Redis

    PG --> PGR

    Web1 --> Prometheus
    Web2 --> Prometheus
    Sidekiq1 --> Prometheus
    Prometheus --> Grafana

    Web1 --> Logs
    Web2 --> Logs
```

---

## Data Flow

### Hash Cracking Data Flow

```mermaid
flowchart LR
    subgraph Input
        Upload[Hash List Upload]
        Config[Attack Configuration]
    end

    subgraph Processing
        Parse[Parse Hashes]
        Store[Store in DB]
        Distribute[Distribute to Agents]
    end

    subgraph Cracking
        Agent1[Agent 1]
        Agent2[Agent 2]
        AgentN[Agent N]
    end

    subgraph Results
        Collect[Collect Cracks]
        Update[Update Hash Items]
        Report[Generate Reports]
    end

    Upload --> Parse
    Parse --> Store
    Config --> Distribute
    Store --> Distribute

    Distribute --> Agent1
    Distribute --> Agent2
    Distribute --> AgentN

    Agent1 --> Collect
    Agent2 --> Collect
    AgentN --> Collect

    Collect --> Update
    Update --> Report
```

---

## API Request Flow

```mermaid
flowchart TB
    Request[API Request] --> Auth{Authenticate}
    Auth -->|Invalid| Reject[401 Unauthorized]
    Auth -->|Valid| Route[Route to Controller]

    Route --> Action[Controller Action]
    Action --> AuthZ{Authorize}
    AuthZ -->|Denied| Forbidden[403 Forbidden]
    AuthZ -->|Allowed| Process[Process Request]

    Process --> Validate{Validate}
    Validate -->|Invalid| BadRequest[400/422 Error]
    Validate -->|Valid| Execute[Execute Logic]

    Execute --> DB[(Database)]
    Execute --> Cache[(Redis Cache)]

    DB --> Response[Build Response]
    Cache --> Response

    Response --> Log[Log Request]
    Log --> Return[Return Response]
```

---

## Priority-Based Task Distribution

```mermaid
flowchart TB
    subgraph "Campaign Priorities"
        Flash[Flash Override<br/>Priority 5]
        Immediate[Immediate<br/>Priority 4]
        Urgent[Urgent<br/>Priority 3]
        Priority[Priority<br/>Priority 2]
        Routine[Routine<br/>Priority 1]
        Deferred[Deferred<br/>Priority -1]
    end

    subgraph "Task Assignment"
        Request[Agent Requests Task]
        Query[Query Available Attacks]
        Sort[Sort by Priority DESC,<br/>Complexity ASC]
        Assign[Assign Task]
    end

    subgraph "Preemption"
        Check{Higher Priority<br/>Attack Waiting?}
        Preempt[Preempt Lower<br/>Priority Task]
        Continue[Continue Current]
    end

    Flash --> Query
    Immediate --> Query
    Urgent --> Query
    Priority --> Query
    Routine --> Query
    Deferred --> Query

    Request --> Query
    Query --> Sort
    Sort --> Check
    Check -->|Yes| Preempt
    Check -->|No| Assign
    Preempt --> Assign
    Continue --> Assign
```
