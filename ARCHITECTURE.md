# Architecture

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=3 --minlevel=1 -->

- [Architecture](#architecture)
  - [Deployment Constraints](#deployment-constraints)
  - [Core Domain Model](#core-domain-model)
  - [Authentication & Authorization](#authentication--authorization)
  - [Project-Based Multi-Tenancy](#project-based-multi-tenancy)
  - [State Machines](#state-machines)
  - [Service Layer](#service-layer)
  - [File Storage & Uploads](#file-storage--uploads)
    - [Storage Backend](#storage-backend)
    - [Resumable File Uploads (tusd)](#resumable-file-uploads-tusd)
    - [Direct Upload (Active Storage, Legacy)](#direct-upload-active-storage-legacy)
  - [Caching & Real-Time](#caching--real-time)
  - [API Structure](#api-structure)
  - [Task Assignment & Agent Lifecycle](#task-assignment--agent-lifecycle)
  - [UI Patterns](#ui-patterns)
  - [Key Dependencies](#key-dependencies)
  - [Configuration Files](#configuration-files)
  - [File Structure](#file-structure)
  - [Related Documentation](#related-documentation)

<!-- mdformat-toc end -->

CipherSwarm is a distributed hash cracking system built on Rails 8.1+, inspired by Hashtopolis. It manages hash-cracking tasks across multiple agents using a web interface with real-time capabilities via Hotwire.

**Current Status**: Undergoing V2 upgrade (see `docs/v2-upgrade-overview.md`)

## Deployment Constraints

Production runs in **air-gapped, non-Internet-connected lab environments**. Development and testing happen on Internet-connected machines. Every architectural decision must be evaluated against these constraints:

- **No Internet access in production** — no CDN assets, no external API calls, no package fetching at runtime. All dependencies must be vendored or bundled into the Docker image at build time.
- **Minimum 10 cracking nodes** — each running an agent process, all submitting status updates, cracks, and heartbeats concurrently.
- **~25 RTX 4090 GPU capacity** — crack submission rates can spike to thousands per second during fast attacks. Status updates arrive every 5–30 seconds per agent.
- **Attack resources exceeding 100 GB** — word lists, rule lists, and mask lists can be 100+ GB. Upload, storage, download, and processing pipelines must handle these sizes without timeouts, memory exhaustion, or filesystem limits.
- **Self-hosted fonts and assets** — all fonts vendored via `@fontsource`; Bootstrap Icons self-hosted. No Google Fonts, no CDN links.
- **Local disk or S3-compatible storage** — production uses local disk by default (`ACTIVE_STORAGE_SERVICE=local`). S3-compatible backends (MinIO, SeaweedFS) are opt-in.
- **Docker Compose is the only supported deployment method** — production runs via `docker-compose.prod.yml` on bare metal or VMs. All services (Rails, Sidekiq, PostgreSQL, Redis, nginx, tusd) are containerized. Scaling is horizontal via `--scale web=N`.

**Decision filter:** "Will this work in production on an isolated LAN with no Internet, 10+ agents, and 100 GB files?"

## Core Domain Model

Four hierarchical concepts:

1. **Campaigns** — Top-level unit of work targeting a single hash list. Contains multiple Attacks executed by priority. Priority-based execution: deferred (-1) → normal (0) → high (2). Higher priority campaigns use preemption to acquire resources from lower priority ones.

2. **Attacks** — Specific hashcat work unit with defined attack type, word lists, and rules. Subdivided into Tasks for parallel processing. Nested under Campaigns (`/campaigns/:id/attacks`). State machine: pending → running → completed/exhausted/failed.

3. **Tasks** — Smallest unit of work assigned to an individual Agent. Tracks progress via HashcatStatus updates. State machine: pending → running → completed/exhausted/failed/paused. Claimed by Agents via API.

4. **Templates** — Reusable attack definitions (attack type + parameters). Not bound to specific hash lists.

## Authentication & Authorization

**Web UI:**

- Devise for user management (sign in, password reset, account management)
- CanCanCan for authorization (`app/models/ability.rb`)
- Rolify for role management
- Admin-only custom actions use deny-first pattern: `cannot :action, Model` in general block + `can :action, Model` in admin block

**Agent API:**

- Bearer token authentication (24-character secure tokens)
- Tokens generated on Agent creation, stored in `agents.token`
- API endpoints at `/api/v1/client/*` (JSON only)
- For unauthenticated endpoints (e.g., health checks), inherit from `ActionController::API` instead of `Api::V1::BaseController`

**HTTP Status Codes:**

- `CanCan::AccessDenied` → 403 Forbidden (authenticated but lacks permission)
- Devise unauthenticated non-HTML requests → 401 Unauthorized
- Administrate dashboard non-admin access → 401 (separate auth mechanism)

## Project-Based Multi-Tenancy

- Projects provide resource isolation and access control
- Agents can be assigned to specific Projects or work across all
- Users have Project-specific roles (via ProjectUser join model)
- Resources (hash lists, campaigns, attacks) scoped to Projects

## State Machines

Three core models use `state_machines-activerecord`:

**Agent States:** pending, active, stopped, error, offline

- Transitions: activate, benchmarked (pending→active), deactivate, shutdown, check_online, check_benchmark_age, heartbeat

**Attack States:** pending → running → completed/exhausted/failed/paused

- Transitions: run, pause, resume, complete, exhaust, fail

**Task States:** pending → running → completed/exhausted/failed/paused

- Transitions: accept, run, complete, pause, resume, error, exhaust, cancel, abandon, preempt, retry
- Tasks track progress via associated HashcatStatus records

> See [GOTCHAS.md § State Machines](GOTCHAS.md#state-machines) for critical edge cases.

## Service Layer

- Controllers are thin (authorization, params, response)
- Complex operations live in model methods or service objects (`app/services/`, 7 services)
- **Models must not call services** — circular dependency risk. Controllers or other services orchestrate.
- Background jobs (`app/jobs/`) handle async operations: `ProcessHashListJob`, `CalculateMaskComplexityJob`, `CountFileLinesJob`, `UpdateStatusJob`, `CampaignPriorityRebalanceJob`, `DataCleanupJob`, `VerifyChecksumJob`

**Service objects and concerns require a REASONING block** explaining: why extracted, alternatives considered, decision rationale, performance implications, future considerations.

## File Storage & Uploads

### Storage Backend

- Default: local disk (`ACTIVE_STORAGE_SERVICE=local`), shared via Docker volume
- S3-compatible storage opt-in: set `ACTIVE_STORAGE_SERVICE=s3` plus `AWS_*` env vars
- Application code is storage-agnostic via ActiveStorage
- `config/storage.yml` defines `:local`, `:test`, and `:s3` services
- **Migration rake task**: `bin/rails storage:migrate_to_local` — idempotent, checksum-verified, interruptible

### Resumable File Uploads (tusd)

tusd (Go binary) runs as a Docker sidecar for chunked, resumable uploads supporting 100+ GB files.

- Upload flow:
  - **Production:** Browser → tus-js-client (50 MB chunks) → nginx (`/uploads/` proxy) → tusd → `/srv/tusd-data`
  - **Dev/Test:** Browser → tus-js-client → tusd directly (Stimulus controller reads `tus_endpoint` helper, backed by `TUS_ENDPOINT_URL` env var)
- On completion: tusd sends HTTP POST hook to `POST /api/v1/hooks/tus` (`Api::V1::Hooks::TusController`)
- Hook caches upload metadata in `Rails.cache`; form controllers use `TusUploadHandler` concern to move file to permanent storage
- `TusUploadHandler` methods: `process_tus_upload` (attack resources → `file_path`) and `process_tus_hash_list_upload` (hash lists → `temp_file_path`)
- **Job enqueuing for tusd uploads happens in `TusUploadHandler`, NOT model callbacks**
- Agent downloads: `Api::V1::Client::FilesController` with nginx `X-Accel-Redirect`
- `TUS_UPLOADS_DIR` env var (default: `/srv/tusd-data`); `ATTACK_RESOURCE_STORAGE_PATH` for permanent storage
- tusd does NOT auto-clean — `tusd-cleanup` Alpine sidecar deletes uploads older than 24 hours
- Resume: tus-js-client stores fingerprint in localStorage; `removeFingerprintOnSuccess: true`

### Direct Upload (Active Storage, Legacy)

- Stimulus controller: `app/javascript/controllers/direct_upload_controller.js`
- Checksum override: `app/javascript/utils/direct_upload_override.js` skips client-side MD5 for files > threshold (default 1 GB)
- Server-side: `config/initializers/active_storage_large_upload.rb` relaxes Blob checksum validation
- `VerifyChecksumJob` computes server-side MD5 post-upload, backfills `blobs.checksum`
- `checksum_verified` boolean column on `word_lists`, `rule_lists`, `mask_lists`

## Caching & Real-Time

- **Do NOT use Solid Cache or Solid Cable** — removed in favor of Redis
- Production Action Cable: Redis adapter (`REDIS_URL`)
- Production cache: `redis_cache_store` with `pool: false` (required for `connection_pool >= 3.0`)
- Development: `async` adapter (no Redis needed)
- Hotwire (Turbo + Stimulus) for interactive UI; `broadcasts_refreshes` on models

## API Structure

**Base Controller:** `app/controllers/api/v1/base_controller.rb` — token auth, project scoping, error handling

**Client API** (`app/controllers/api/v1/client/`):

- `agents_controller.rb` — heartbeat, benchmarks, errors, shutdown
- `attacks_controller.rb` — attack details, hash list download
- `tasks_controller.rb` — task lifecycle (new, accept, status, crack submission, abandon)
- `crackers_controller.rb` — cracker binary updates

**API Documentation:**

- RSwag for OpenAPI/Swagger; tests in `spec/requests/` generate docs
- `just docs-api` or `RAILS_ENV=test rails rswag` to regenerate
- vacuum lints the OpenAPI spec (`just lint-api`)

> See [GOTCHAS.md § API & rswag](GOTCHAS.md#api--rswag) for rswag 3.0.0.pre migration notes.

## Task Assignment & Agent Lifecycle

- Agents request tasks via `GET /api/v1/client/tasks/new`
- **Security:** Task queries must be scoped to the current agent (`.where(agent: agent)`)
- Tasks claimed with `claimed_by_agent_id` and `expires_at`
- `tasks.agent_id` is NOT NULL — never set to nil. On shutdown, tasks are paused and claim fields cleared.
- Grace period (`agent_considered_offline_time`, default 30 min) via `paused_at` column
- `TaskAssignmentService#find_own_paused_task` runs first — returning agents reclaim their own paused tasks

**Agent Error Metadata Contract** (`POST /api/v1/client/agents/:id/submit_error`):

- `category` — `hash_format`, `hardware`, `runtime`, `config`
- `retryable` / `terminal` — boolean flags for error severity
- `error_type` — machine-readable identifier
- Server-side code should match on structured fields, not raw message text

## UI Patterns

**Layout:** `col-md-10` when sidebar present (logged in), `col-12` when not. Bootstrap offcanvas for mobile.

**Toast Notifications:** Error toasts persist (no auto-hide); success/info auto-dismiss after 5 seconds.

**Pagination (Pagy):** `<%== @pagy.series_nav(:bootstrap) %>` with `<noscript>` fallback. Guard with `if pagy.pages > 1`.

**Tom Select:** Stimulus controller at `app/javascript/controllers/select_controller.js`. Use `label_method: :to_s` in SimpleForm.

**Theme:** Catppuccin Macchiato dark palette. `$ctp-violet: #a855f7` primary accent. Surface hierarchy: Crust (navbar) → Mantle (sidebar) → Base (body) → Surface0 (cards). Self-hosted fonts: Space Grotesk (headings), IBM Plex Sans (body), JetBrains Mono (code).

## Key Dependencies

| Gem                           | Purpose                                    |
| ----------------------------- | ------------------------------------------ |
| `state_machines-activerecord` | State machines for Agent, Attack, Task     |
| `cancancan`                   | Authorization rules                        |
| `rolify`                      | Role management                            |
| `audited`                     | Model change tracking                      |
| `paranoia`                    | Soft deletes (Campaign)                    |
| `ar_lazy_preload`             | N+1 query prevention                       |
| `pagy`                        | Pagination                                 |
| `view_component`              | Reusable UI components                     |
| `sidekiq` / `sidekiq-cron`    | Background jobs and scheduling             |
| `store_model`                 | JSON column typing (AdvancedConfiguration) |
| `anyway_config`               | Configuration management                   |

**Runtime note:** `ApplicationConfig` (Anyway::Config) loads from env vars at startup — no runtime reload. Changes require process restart.

## Configuration Files

| File                  | Purpose                                                                       |
| --------------------- | ----------------------------------------------------------------------------- |
| `justfile`            | Task runner (`just --list` for all commands)                                  |
| `Procfile.dev`        | Development processes (web, CSS, JS)                                          |
| `.rubocop.yml`        | RuboCop config (inherits rubocop-rails-omakase)                               |
| `config/routes.rb`    | Routes: `draw(:admin)`, `draw(:client_api)`, `draw(:errors)`, `draw(:devise)` |
| `swagger_helper.rb`   | OpenAPI config (requires `spec/support/rswag_polyfills.rb`)                   |
| `vacuum-ruleset.yaml` | OpenAPI lint rules                                                            |

## File Structure

```
app/
├── components/        # ViewComponent classes
├── controllers/
│   ├── api/v1/       # Agent API
│   ├── admin/        # Administrate overrides
│   └── concerns/     # TusUploadHandler, TaskErrorHandling, Downloadable
├── errors/           # Operational errors (InsufficientTempStorageError)
├── jobs/             # Background jobs
├── models/
│   └── concerns/     # State machines, AttackResource, SafeBroadcasting
├── services/         # Service objects (7)
└── validators/       # Custom validations
```

## Related Documentation

- [GOTCHAS.md](GOTCHAS.md) — edge cases and hard-won lessons
- [CONTRIBUTING.md](CONTRIBUTING.md) — code standards and workflow
- [docs/deployment/](docs/deployment/) — Docker, air-gapped deployment, env vars
- [docs/development/](docs/development/) — developer guide, logging, style guide
- [docs/testing/](docs/testing/) — system tests guide, testing strategy
