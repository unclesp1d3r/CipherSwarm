# Phase 1: Core Infrastructure Setup

## ✅ Base SQLAlchemy Configuration

-   [x] Async SQLAlchemy engine with pooling
-   [x] Base model with `id`, `created_at`, `updated_at` fields
-   [x] Session management using dependency injection
-   [x] Health check system via FastAPI route

---

## 🧩 Core Models Implementation

### 👤 User Model

-   [ ] Integrate `fastapi-users` for authentication and session handling
-   [ ] Extend base user model to include:
    -   `name`, `role` (enum: `admin`, `analyst`, `operator`)
    -   Login metadata: `sign_in_count`, `current_sign_in_at`, `last_sign_in_at`, `current_sign_in_ip`, `last_sign_in_ip`
    -   Security: `reset_password_token`, `unlock_token`, `failed_attempts`
    -   Indexes: `email` (unique), `name` (unique), `reset_password_token` (unique)
    -   Optional: TOTP 2FA field

### 📁 Project Model

-   [ ] Fields: `name`, `description`, `private`, `archived_at` (optional), `notes` (optional)
-   [ ] M2M Relationship with Users via association table
-   [ ] Index: `name` (unique)

### 🧠 OperatingSystem Model

-   [ ] Fields: `name` (enum: `windows`, `linux`, `darwin`), `cracker_command`
-   [ ] Index: `name` (unique)
-   [ ] Validation: Enum enforcement via Pydantic and DB constraint

### 🛰 Agent Model

-   [ ] Fields:
    -   Identity: `client_signature`, `host_name`, `custom_label`
    -   Auth: `token`, `last_seen_at`, `last_ipaddress`
    -   State: `state` (enum: `pending`, `active`, `error`, `offline`, `disabled`), `enabled` (bool)
    -   Config: `advanced_configuration` (JSON)
    -   Devices: `devices` (array of dicts with type, model, hash rate, etc.)
    -   Metadata: `agent_type` (optional: `physical`, `virtual`, `container`)
-   [ ] M2M with Projects
-   [ ] Indexes: `token` (unique), `state`, `custom_label` (unique)
-   [ ] Relationships: `operating_system_id`, `user_id`

### ⚠️ AgentError Model

-   [ ] Fields: `message`, `severity`, `error_code`, `metadata` (JSON)
-   [ ] Timestamps: `created_at`, `updated_at`
-   [ ] Indexes: `agent_id`, `task_id`
-   [ ] Relationships: `agent_id`, `task_id`

### 💥 Attack Model

-   [ ] Fields: `name`, `description`, `state`, `hash_type` (enum)
-   [ ] Configuration block:
    -   Mode: `attack_mode` (enum)
    -   Masks: `mask`, `increment_mode`, `increment_minimum`, `increment_maximum`
    -   Performance: `optimized`, `workload_profile`, `slow_candidate_generators`
    -   Markov: `disable_markov`, `classic_markov`, `markov_threshold`
    -   Rules: `left_rule`, `right_rule`
    -   Charsets: `custom_charset_1`, `custom_charset_2`, `custom_charset_3`, `custom_charset_4`
-   [ ] Scheduling: `priority`, `start_time`, `end_time`
-   [ ] Relationships: `campaign_id`, `rule_list_id`, `word_list_id`, `mask_list_id`
-   [ ] Indexes: `campaign_id`, `state`
-   [ ] Optional: Template linkage for cloning

### 🧾 Task Model

-   [ ] Fields:
    -   `state`, `stale`
    -   `start_date`, `end_date`, `completed_at`
    -   `progress_percent`, `progress_keyspace`
    -   `result_json` (structured output)
    -   `agent_id`, `attack_id`
-   [ ] Indexes: `agent_id`, `state`, `completed_at`

---

## ✅ Notes for Cursor

-   Always use `Pydantic` v2 for schema validation and enforce field enums explicitly.
-   Use `SQLAlchemy` async ORM with Alembic for all model migrations.
-   All models must have matching `CRUD` FastAPI routers defined by end of Phase 2.
-   Enums must be validated both in schema and in SQL constraints.
-   Use helper services for non-trivial logic such as token validation or benchmark processing.
