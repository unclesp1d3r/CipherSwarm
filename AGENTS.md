# AGENTS.md

This file provides guidance to Agents when working with code in this repository.

@GOTCHAS.md

> **See also:** [GOTCHAS.md](GOTCHAS.md) — edge cases, hard-won lessons, and "watch out for" patterns organized by domain. Read the relevant section before working in that area.

@DESIGN.md

## Project Overview

CipherSwarm is a distributed hash cracking system built on Rails 8.1+ inspired by Hashtopolis. It manages hash-cracking tasks across multiple agents using a web-based interface with real-time capabilities via Hotwire.

**Current Status**: Undergoing V2 upgrade (see docs/v2-upgrade-overview.md)

## Code Quality Policy

- **Zero tolerance for tech debt.** Never dismiss warnings, lint failures, or CI errors as "pre-existing" or "not from our changes." If CI fails, investigate and fix it — regardless of when the issue was introduced. Every session should leave the codebase better than it found it.

## Privacy in Documentation

- Never include actual usernames, real names, or PII in code/documentation/examples
- Use `$USER`, `unclesp1d3r` (public pseudonym), or generic placeholders instead
- Applies to all files: code, docs, comments, examples, commit messages

## Development Tools

This project uses [mise](https://mise.jdx.dev/) for development tool version management. All tool versions are defined in `mise.toml`:

- **Ruby** - Application runtime (pinned version)
- **Bun** - JavaScript runtime and package manager (replaces Node.js + npm/yarn)
- **Just** - Task runner (like make, but simpler)
- **Pre-commit** - Git hooks for code quality
- **Docker Compose** - Container orchestration
- **Git-cliff** - Changelog generator
- **Oxlint** - Fast JavaScript/TypeScript linter
- **Vale** - Prose linter for documentation

Install mise first, then run `mise install` to get all tools at the correct versions.

**Bun** is used instead of npm/yarn for JavaScript dependency management. It's faster and provides a compatible API. Use `bun install`, `bun run`, `bun add`, etc.

**Environment Isolation:**

- `.envrc` file ensures clean environment isolation between projects
- Automatically unsets `TEST_DATABASE_URL` from other projects (e.g., Ouroboros)
- direnv integration via mise or oh-my-zsh activates on `cd` into directory
- Rails uses system user (`$USER`) for local PostgreSQL when no DATABASE_URL is set

## Common Development Commands

### Setup and Installation

```bash
# Setup project (install deps + prepare database)
just setup

# Or manually
bun install
bin/setup --skip-server

# Start development server (Rails + assets + Sidekiq)
just dev
# or manually
bin/dev
```

### Testing

```bash
# Run all tests with coverage
just test
# or
COVERAGE=true bundle exec rspec

# Run specific test file
just test-file spec/models/agent_spec.rb
# or
bundle exec rspec spec/models/agent_spec.rb

# Run system tests (UI/UX tests with Capybara)
just test-system
# or
bundle exec rspec spec/system

# Run system tests with visible browser (debugging)
HEADLESS=false bundle exec rspec spec/system

# Run API tests
just test-api
# or
bundle exec rspec spec/requests

# Test database connection (if local PostgreSQL conflicts with Docker)
# Stop local PostgreSQL: brew services stop postgresql@17
# Start Docker PostgreSQL: docker compose up -d postgres-db
# Run tests with explicit URL:
# Docker PG binds to IPv6 (*:5432) — use `localhost` not `127.0.0.1`
TEST_DATABASE_URL=postgres://root:password@localhost:5432/cipher_swarm_test bundle exec rspec
```

### Code Quality

```bash
# Run all linters and security checks
just check

# Auto-format code
just format

# Run RuboCop
just lint

# Run Brakeman security scanner
just security

# Lint OpenAPI specification with vacuum
just lint-api
```

**Always use `just` recipes** instead of raw `bundle exec` commands. The justfile handles binstubs and `mise exec` correctly. Raw `bundle exec rubocop` can fail when Gemfile has GitHub git sources (e.g., rswag from master).

### Undercover (Change-Based Coverage)

```bash
# Check test coverage for changed code vs origin/main
just undercover

# Full CI pipeline: pre-commit → brakeman → rspec (with coverage) → undercover → API tests → rswag
just ci-check
```

- Undercover requires `COVERAGE=true` RSpec run first to generate `coverage/lcov.info`
- CI needs `fetch-depth: 0` in checkout for undercover to access origin/main
- To fix undercover failures: add tests covering the flagged lines, then re-run `just ci-check`
- `retry_on` / `discard_on` block bodies are unreachable via `perform_now` — undercover flags them as uncovered. `# :nocov:` does NOT help (undercover still flags `n/a` lines). Workaround: extract handler to a lambda constant and pass via `&CONSTANT` — lambda body gets coverage at class load time. See `ApplicationJob::TEMP_STORAGE_DISCARD_HANDLER` for the pattern.

### Database Operations

```bash
# Run migrations
just db-migrate

# Rollback last migration
just db-rollback

# Reset database (drop, create, migrate, seed)
just db-reset

# Create new migration (ALWAYS use Rails generators)
just db-migration AddFieldToModel
# or
bin/rails generate migration AddFieldToModel
```

### Asset Pipeline

```bash
# Build all assets (CSS + JS)
just assets-build

# Watch assets for changes
just assets-watch
```

### Catppuccin Macchiato Theme

- `_catppuccin.scss` defines the full palette + Bootstrap variable overrides — imported BEFORE `@import "bootstrap"`
- Primary accent: `$ctp-violet: #a855f7` (DarkViolet lightened), not Catppuccin's Mauve
- Surface hierarchy: Crust (navbar) → Mantle (sidebar) → Base (body) → Surface0 (cards/inputs)
- `application.bootstrap.scss` adds component-level dark theme overrides (cards, tables, dropdowns, inputs, Tom Select)
- Self-hosted fonts via `@fontsource`: Space Grotesk (headings), IBM Plex Sans (body), JetBrains Mono (code) — air-gap safe
- Font woff2 files copied to `app/assets/builds/` by `build:css:fonts` script in package.json

### API Documentation

```bash
# Generate Swagger/OpenAPI documentation
just docs-api
# or
RAILS_ENV=test rails rswag

# Run integration tests and generate API docs
just docs-generate
```

### Background Jobs

```bash
# Start Sidekiq worker
just sidekiq

# Clear Sidekiq queues
just sidekiq-clear

# Access Sidekiq web UI at http://localhost:3000/sidekiq (admin users only)
```

## High-Level Architecture

### Core Domain Model

CipherSwarm is built around four hierarchical concepts:

1. **Campaigns** - Top-level unit of work targeting a single hash list

   - Contains multiple Attacks executed based on priority
   - Priority-based execution model (deferred (-1) → normal (0) → high (2))
   - Higher priority campaigns use intelligent preemption to acquire resources from lower priority campaigns
   - Belongs to a Project and HashList

2. **Attacks** - Specific hashcat work unit with defined attack type, word lists, and rules

   - Can be subdivided into Tasks for parallel processing across Agents
   - Nested resource under Campaigns (create via `/campaigns/:id/attacks`)
   - State machine: pending → running → completed/exhausted/failed

3. **Tasks** - Smallest unit of work assigned to an individual Agent

   - Represents a segment of an Attack for distributed execution
   - Tracks progress via HashcatStatus updates
   - State machine: pending → running → completed/exhausted/failed/paused
   - Can be claimed by Agents via API

4. **Templates** - Reusable attack definitions (attack type + parameters)

   - Not bound to specific hash lists
   - Enables rapid configuration of new attacks

### Authentication & Authorization

**Web UI:**

- Rails 8 built-in authentication with secure session cookies
- Devise for user management (sign in, password reset, account management)
- CanCanCan for authorization (see app/models/ability.rb)
- Rolify for role management

**Agent API:**

- Bearer token authentication (24-character secure tokens)
- Tokens generated on Agent creation, stored in `agents.token`
- API endpoints at `/api/v1/client/*` (JSON only)
- Authentication flow: Agent authenticates → receives configuration → processes tasks
- For **unauthenticated** endpoints (e.g., health checks), inherit from `ActionController::API` instead of `Api::V1::BaseController` to bypass `authenticate_agent`. Use `security []` in the rswag spec to override the global `bearer_auth` requirement.

### Project-Based Multi-Tenancy

- Projects provide resource isolation and access control
- Agents can be assigned to specific Projects or work across all Projects
- Users have Project-specific roles (managed via ProjectUser join model)
- Resources (hash lists, campaigns, attacks) scoped to Projects

### State Machines

Three core models use state_machines-activerecord:

**Agent States:** pending, active, stopped, error, offline

- Transitions: activate, benchmarked (pending→active), deactivate, shutdown, check_online, check_benchmark_age, heartbeat

**Attack States:** pending → running → completed/exhausted/failed/paused

- Transitions: run, pause, resume, complete, exhaust, fail

**Task States:** pending → running → completed/exhausted/failed/paused

- Transitions: accept, run, complete, pause, resume, error, exhaust, cancel, abandon, preempt, retry
- Tasks track progress via associated HashcatStatus records

> **Critical gotchas** for all three state machines — see [GOTCHAS.md § State Machines](GOTCHAS.md#state-machines)

### Service Layer Pattern

Business logic is extracted into service objects and models:

- Controllers are kept thin (authorization, params, response)
- Complex operations live in model methods (not separate service objects currently)
- **Models must not call services** — this creates circular dependencies (model→service→model). Controllers or other services are the correct orchestration layer for service invocations.
- Background jobs in app/jobs/ handle async operations:
  - `ProcessHashListJob` - Process uploaded hash lists
  - `CalculateMaskComplexityJob` - Calculate mask complexity
  - `CountFileLinesJob` - Count lines in uploaded files
  - `UpdateStatusJob` - Update task status
  - `CampaignPriorityRebalanceJob` - Trigger task preemption when campaign priority is raised
  - `DataCleanupJob` - Data retention enforcement (old errors, audits, hashcat statuses)
  - `VerifyChecksumJob` - Deferred server-side checksum verification for large-file uploads that skipped client-side MD5

### File Storage

- Active Storage for file uploads (hash lists, word lists, rule lists, mask lists)
- AWS S3 for production storage
- Local disk storage for development
- File validation via ActiveStorageValidations gem

### Pagy 43 Pagination Rendering

- All paginated views must use `<%== @pagy.series_nav(:bootstrap) %>` with a `<noscript><%== @pagy.series_nav %></noscript>` fallback
- Some views use a local `pagy` variable (from partials) instead of `@pagy` — same API applies
- Guard both `series_nav` and `<noscript>` inside `if pagy.pages > 1` (see `campaigns/_error_log.html.erb` for reference)
- Pagination uses inline `series_nav(:bootstrap)` calls directly in views (no wrapper component)

### Caching & Real-Time Backend

- **Do NOT use Solid Cache or Solid Cable** — removed in favor of Redis (see cable.yml, production.rb)
- Production Action Cable: Redis adapter (`REDIS_URL`)
- Production cache store: `redis_cache_store` with `pool: false` (required for `connection_pool >= 3.0`)
- Development Action Cable: `async` adapter (no Redis needed)

### Real-Time Features

- Hotwire (Turbo + Stimulus) for interactive UI
- Turbo Streams for real-time updates
- `broadcasts_refreshes` on models to push updates to clients
- Action Cable via Redis in production, async in development

### Admin Interface

- Administrate gem for admin dashboard at `/admin`
- Admin-only Sidekiq Web UI at `/sidekiq`
- Custom admin actions in AdminController (user locking, etc.)

### API Structure

**Base Controller:** `/app/controllers/api/v1/base_controller.rb`

- Token-based authentication
- Project scoping
- Error handling

**Client API:** `/app/controllers/api/v1/client/*`

- `client_controller.rb` - Configuration, authentication
- `client/agents_controller.rb` - Agent heartbeat, benchmarks, errors, shutdown
- `client/attacks_controller.rb` - Attack details, hash list download
- `client/crackers_controller.rb` - Cracker binary updates
- `client/tasks_controller.rb` - Task lifecycle (new, accept, status, crack submission, abandon)

**API Documentation:**

- RSwag for OpenAPI/Swagger documentation
- Tests in spec/requests/ generate documentation
- Run `just docs-api` or `RAILS_ENV=test rails rswag` to regenerate
- [vacuum](https://quobix.com/vacuum/) lints the generated OpenAPI spec (`just lint-api`)
- Custom ruleset in `vacuum-ruleset.yaml` disables rules that conflict with Rails conventions
- Use `request_body_json schema: {...}, examples: :let_name` for request bodies (polyfilled in spec/support/rswag_polyfills.rb for rswag 3.0.0.pre)

> **rswag 3.0.0.pre migration notes** — see [GOTCHAS.md § API & rswag](GOTCHAS.md#api--rswag)

#### JavaScript Testing

Vitest for JS unit tests:

1. Install: `bun add -D vitest jsdom @testing-library/dom @hotwired/stimulus`
2. Config: `vitest.config.js` in project root with `environment: 'jsdom'`
3. Setup: `spec/javascript/setup.js` initializes Stimulus Application
4. Run: `just test-js` or `npx vitest run`

- Pagy JS is distributed via the gem's `javascripts/` directory, not npm — `config/initializers/pagy.rb` adds it to asset paths and esbuild resolves via `NODE_PATH`
- Run `bin/rails stimulus:manifest:update` after adding/removing Stimulus controllers — the manifest can drift if controllers are added manually

> **Vitest mock patterns** — see [GOTCHAS.md § API & rswag](GOTCHAS.md#api--rswag)

### For planning agents

When planning new features or architectural changes, use the `layered-rails` skill for analysis:

- `/layers:gradual` — plan incremental adoption of layered patterns
- `/layers:analyze` — full codebase architecture analysis
- `/layers:review` — review code from a layered architecture perspective
- `/layers:spec-test` — apply the specification test to evaluate layer placement

## Testing Strategy

**System Tests (spec/system/):**

- Page Object Pattern (page objects in spec/support/page_objects/)
- Capybara + Selenium WebDriver with Chrome
- Screenshots on failure (tmp/capybara/)
- Key workflows: authentication, agent management, campaigns, file uploads, authorization
- See docs/testing/system-tests-guide.md

**Model Tests (spec/models/):**

- FactoryBot factories (spec/factories/)
- Comprehensive validation and association testing
- State machine transition testing

**Request Tests (spec/requests/):**

- API endpoint testing
- Generates Swagger documentation via RSwag
- Authentication and authorization testing

**View Tests (spec/views/) — planned:**

- Partial rendering tests (e.g., agent configuration tab)
- Use `render partial:` with locals, assert on `rendered`
- Stub `safe_can?` when the partial uses authorization checks

**Non-Standard Spec Directories:**

- `spec/performance/` - Page load benchmarks and query count efficiency tests
- `spec/deployment/` - Air-gapped deployment validation (CDN-free assets, Docker config, offline readiness)
- `spec/coverage/` - Coverage verification (validates spec file existence across layers)
- These use `# rubocop:disable RSpec/DescribeClass` since they describe behaviors, not classes

> **Testing gotchas** (CI scope, Turbo Streams, state machines, deadlocks, cache keys, etc.) — see [GOTCHAS.md § Testing](GOTCHAS.md#testing)

### Key Gems and Their Purposes

- **state_machines-activerecord** - State machines for Agent, Attack, Task
- **cancancan** - Authorization rules (app/models/ability.rb)
- **rolify** - Role management
- **audited** - Model change tracking
- **paranoia** - Soft deletes (Campaign model)
- **ar_lazy_preload** - N+1 query prevention
- **pagy** - Pagination
- **view_component** - Reusable UI components (app/components/)
- **sidekiq** - Background job processing
- **sidekiq-cron** - Scheduled jobs
- **store_model** - JSON column typing (AdvancedConfiguration)
- **anyway_config** - Configuration management

**Runtime Mutability:**

- ApplicationConfig (Anyway::Config) is loaded from environment variables at startup with no runtime reload mechanism — changes require a process restart
- Do not build admin UI forms for editing ApplicationConfig values — use a database-backed model if runtime-editable settings are needed

### Code Organization Standards

From .cursor/rules/core-principals.mdc and rails.mdc:

**Service Objects and Concerns:**

- All service objects and concerns require a REASONING block in comments explaining:
  - Why this extraction was made
  - Alternatives considered
  - Decision rationale
  - Performance implications (if any)
  - Future considerations (if any)

**File Structure:**

- Business logic: app/models/ and app/services/ (7 service objects)
- API endpoints: app/controllers/api/v1/
- View components: app/components/
- Custom validations: app/validators/
- Background jobs: app/jobs/
- Custom errors: app/errors/ — operational/infrastructure errors (e.g., `InsufficientTempStorageError`). Domain validation errors belong with their models, not here.

**Documentation Indexes:**

- When adding new files to `docs/user-guide/`, update BOTH `docs/user-guide/README.md` (user guide index) AND `docs/README.md` (top-level docs index) with links to the new files
- `docs/user-guide/README.md` includes a "What's New in V2" section and a Quick Navigation table that also need updating for new features
- When adding new files to `docs/deployment/`, update `docs/README.md` with links to the new files
- `docs/deployment/air-gapped-deployment.md` is the DevOps-focused guide; `docs/user-guide/air-gapped-deployment.md` is the user-focused version with the 10-item validation checklist
- `docs/plans/` is gitignored — working implementation documents, stay local only
- `docs/solutions/` is committed — operational knowledge base for deployers and future sessions
- AGENTS.md and GOTCHAS.md remain the canonical project documentation (always committed)

**Ruby Style:**

- Target Ruby 3.2+, frozen string literals
- 120 character line length, 2 space indentation
- Methods in alphabetical order (except initialize, CRUD actions)
- Maximum 4 parameters per method
- Use RuboCop with Rails Omakase configuration
- Bang methods (`method!`) must use bang ActiveRecord calls (`update!`, `save!`) — raise on failure, don't return false

**Testing Standards:**

- Maximum 20 lines per RSpec example
- Maximum 5 expectations per example
- Use FactoryBot factories, not fixtures
- Test both happy and edge cases

**Migration Generation:**

- ALWAYS use Rails generators for migrations
- Never create migration files manually
- Use `bin/rails generate migration` or `just db-migration`

> **Migration gotchas** (schema drift, unique index cleanup) — see [GOTCHAS.md § Database & ActiveRecord](GOTCHAS.md#database--activerecord)

**Feature Removal Checklist:**

- `db/seeds.rb` - Remove any model creation calls
- `spec/swagger_helper.rb` - Remove API tags and schema definitions
- `swagger/v1/swagger.json` - Regenerate with `RAILS_ENV=test rails rswag`
- Migration `down` method - Add comment if simplified (won't restore full functionality)

### Important Configuration Files

- **justfile** - Task runner with common commands (see `just --list`)
- **Procfile.dev** - Development processes (web, CSS, JS)
- **.rubocop.yml** - RuboCop configuration (inherits from rubocop-rails-omakase)
- **config/routes.rb** - Routes organized with `draw(:admin)`, `draw(:client_api)`, `draw(:errors)`, `draw(:devise)`
- **swagger_helper.rb** - OpenAPI/Swagger configuration (requires `spec/support/rswag_polyfills.rb` for rswag 3.x bridge code)
- **spec/openapi_helper.rb** - rswag 3.x compatibility shim that delegates to `swagger_helper.rb`
- **spec/support/rswag_polyfills.rb** - Temporary rswag 3.0.0.pre polyfills (`request_body_json` DSL, `LetFallbackHash`, `RequestFactoryLetFallback`); version-guarded to fail on rswag upgrade

### Tom Select (Searchable Dropdowns)

- Stimulus controller: `app/javascript/controllers/select_controller.js`
- Supports `data-select-allow-empty-value` and `data-select-max-options-value` attributes
- CSS: `tom-select/dist/css/tom-select.bootstrap5` imported in application.bootstrap.scss
- System test helper: `BasePage#tom_select_fill_and_choose(select_id, text)` — requires `dropdown_input` plugin
- SimpleForm: use `label_method: :to_s` explicitly rather than adding `to_label` to models

### Direct Upload Progress (Active Storage)

- Stimulus controller: `app/javascript/controllers/direct_upload_controller.js`
- Attached to `<form>` element (not a wrapper div) — Active Storage events bubble from file input to form
- Two-phase progress: "Preparing... X%" during checksum hashing, then "Uploading... X%" during transfer
- Progress bar HTML extracted to `app/views/shared/_direct_upload_progress.html.erb` (used by all 3 forms)
- Used on: `hash_lists/_form`, `mask_lists/_form`, `shared/attack_resource/_form`
- Checksum override: `app/javascript/utils/direct_upload_override.js` patches `FileChecksum.create` (imported from internal path `@rails/activestorage/src/file_checksum`, NOT the package root which doesn't export it) to skip client-side MD5 for files exceeding the threshold (default 1 GB) — `blobs.checksum` is NULL for skipped files
- For files under threshold, the override emits `direct-upload:checksum-progress` events on `document` during hashing (FileChecksum has no reference to the input element)
- Override threshold is scoped per-file via a WeakMap (not a mutable global), set from the Stimulus controller's `checksumThresholdValue` during `direct-upload:initialize`
- Server-side nil-checksum support: `config/initializers/active_storage_large_upload.rb` relaxes Blob checksum validation (allows nil when `metadata.checksum_skipped == true`), and patches S3 service to omit nil `Content-MD5` header — uses targeted validator removal (NOT `clear_validators!`)
- Custom `app/controllers/active_storage/direct_uploads_controller.rb` overrides the base controller to accept nil checksum and set `checksum_skipped` metadata
- Deferred verification: `VerifyChecksumJob` computes server-side MD5 post-upload, backfills `blobs.checksum`, and sets `checksum_verified: true` on the attack resource — uses `blob.service.open(blob.key, ..., verify: false)` to skip the Downloader's integrity check
- `checksum_verified` boolean column on `word_lists`, `rule_lists`, `mask_lists` (default `true`) — set to `false` on upload of large files, `true` after `VerifyChecksumJob` completes
- Override threshold tunable per-form via `data-direct-upload-checksum-threshold-value` attribute (bytes); defaults to 1 GB if not specified
- `app/javascript/utils/` is the directory for shared JS utility modules (not controllers)

### Common Patterns

**Layout Grid (Logged-In vs Logged-Out):**

- Main content column is conditional: `col-md-10` when sidebar present (logged in), `col-12` when not
- Sidebar uses `d-none d-md-block` (hidden on mobile) + Bootstrap offcanvas (`#sidebarOffcanvas`) for mobile navigation
- Mobile offcanvas includes sidebar nav AND navbar items (Tools, Account) via `_sidebar_navbar_items.html.erb`
- Flash messages rendered inline in layout: `notice` → `alert-success`, `alert` → `alert-danger`, `info` → `alert-info`
- Skip link (`visually-hidden-focusable`) is first child of `<body>`, targets `id="main-content"` on `<main>`

**Toast Notifications:**

- Error/danger toasts persist (no auto-hide) — users must manually dismiss via close button
- Success/warning/info toasts auto-dismiss after 5 seconds
- `ToastNotificationComponent#autohide?` returns `false` for `danger` variant

**Boolean Column Conventions:**

- Always define both positive and negative scopes: `scope :quarantined` + `scope :not_quarantined`
- Bang lifecycle methods use `update!` (not `update`) — consistent with the bang convention
- Explicit predicate methods (`quarantined?`) with `super` delegation are acceptable for API discoverability

**Active Storage Change Detection:**

- `saved_change_to_file?` does NOT exist for Active Storage attachments
- Use `file.attachment&.saved_change_to_blob_id?` inside `after_commit` to detect when the attached file blob was swapped

**Active Storage Attachment Guards:**

- `record.file.nil?` is always `false` for `has_one_attached` — the proxy object exists even when nothing is attached
- Use `!record.file.attached?` to guard against purged/missing files
- `TempStorageValidation` concern guards with `return if blob.nil?` (blob is nil after purge, even though the attachment proxy isn't)

**Nested Resources:**

- Attacks are nested under Campaigns: `/campaigns/:campaign_id/attacks`
- Create attacks via `new_campaign_attack_path(campaign)`

**Custom Member Actions:**

- Use `redirect_back_or_to` (not `redirect_to`) for actions callable from multiple pages (index, show)

**Priority-Based Execution:**

- Campaign priority enum: deferred (-1) → normal (0) → high (2)
- Higher priority campaigns use intelligent preemption to acquire resources from lower priority ones
- Callback `trigger_priority_rebalance_if_needed` enqueues `CampaignPriorityRebalanceJob` when priority is raised

**Task Action State Requirements (TaskActionsComponent):**

- `can_cancel?` requires `task.pending?` or `task.running?` (+ authorization)
- `can_retry?` requires `task.failed?` (+ authorization)
- `can_reassign?` requires `task.pending?`, `task.running?`, `task.failed?`, or `task.paused?` (+ authorization)
- `can_download_results?` requires `task.completed?` or `task.exhausted?` (+ authorization)
- Tests must create tasks in the correct state for action buttons to render

**HashItem Scoping:**

- `hash_items.attack_id` tracks which attack cracked a hash, but there is no `task_id` — per-task attribution unavailable
- When scoping results to a task, use `HashItem.where(hash_list: task.hash_list, attack: task.attack, cracked: true)`

**Agent Task Assignment:**

- Agents request tasks via `GET /api/v1/client/tasks/new`
- **Security:** Task queries in service objects must be scoped to the current agent (`.where(agent: agent)`) to prevent authorization bypass
- Tasks claimed with `claimed_by_agent_id` and `expires_at`
- **`tasks.agent_id` is NOT NULL** — never set to nil. On agent shutdown, tasks are paused and claim fields (`claimed_by_agent_id`, `claimed_at`, `expires_at`) are cleared. `TaskAssignmentService#find_unassigned_paused_task` detects orphans using a `paused_at` grace period, then reassigns `agent_id` and calls `resume!` on pickup.
- `TaskAssignmentService#find_own_paused_task` runs before `find_unassigned_paused_task` — returning agents reclaim their own paused tasks first (to use restore files)
- Grace period (`agent_considered_offline_time`, default 30 min) via `paused_at` column: within the period, only the original agent can reclaim; after, any agent can. Tasks from offline/stopped agents are available immediately.
- When reclaiming a paused task whose attack was also paused (shutdown cascade), the attack is resumed automatically
- Agents submit status updates via `POST /api/v1/client/tasks/:id/submit_status`
- Agents submit cracks via `POST /api/v1/client/tasks/:id/submit_crack`

**Agent Error Metadata Contract:**

- Agent errors submitted via `POST /api/v1/client/agents/:id/submit_error` include structured metadata in `metadata.other`:
  - `category` — error domain: `hash_format`, `hardware`, `runtime`, `config`
  - `retryable` — boolean: whether the error is transient (`true`) or permanent (`false`)
  - `terminal` — boolean: definitive failures where no retry can succeed (e.g., `no_hashes_loaded`)
  - `error_type` — machine-readable identifier: `token_length_exception`, `no_hashes_loaded`, `hashfile_empty_or_corrupt`, etc.
  - `affected_count` / `total_count` — for hash parse failures, how many hashes failed vs total
- Server-side code that evaluates error severity should match on these structured fields, not raw message text

**Authorization Flow:**

- CanCanCan abilities defined in app/models/ability.rb
- `authorize!` in controllers
- Project-based scoping for all resources
- Admin users have unrestricted access
- Admin-only custom actions use deny-first pattern: `cannot :action, Model` in general block + `can :action, Model` in admin block — prevents `can :manage, Campaign` (project-scoped) from granting the ability to non-admins
- `CanCan::AccessDenied` returns 403 Forbidden (authenticated but lacks permission)
- Devise unauthenticated non-HTML requests (CSV, JSON) return 401 Unauthorized
- Administrate dashboard non-admin access returns 401 (separate auth mechanism, not CanCan)

**Bulk Replacements — Be Judicious:**

- Never blindly find-and-replace across test files — different contexts use the same text for different reasons
- Example: `:unauthorized` (401) appears in both CanCan authorization tests and Devise authentication tests; bulk-replacing all to `:forbidden` breaks the Devise cases
- Always inspect each occurrence to understand whether it's an authentication failure (401) or an authorization failure (403) before changing

> **More pattern gotchas** (CanCanCan nesting, nullable params, Redis locks, logging, upsert_all, FK cascades, transactions) — see [GOTCHAS.md § Database & ActiveRecord](GOTCHAS.md#database--activerecord) and [GOTCHAS.md § Infrastructure](GOTCHAS.md#infrastructure)

**Railsboot Component Removal (Complete):**

- Railsboot components (`app/components/railsboot/`) have been fully removed
- All views now use plain ERB + Bootstrap utility classes directly
- Bootstrap JS dependencies: dropdowns, offcanvas, toasts (via Stimulus), modals, collapse

### Development Workflow

1. Use `just dev` to start the development server (Rails + assets + Sidekiq)
2. Run tests frequently with `just test` or `just test-file spec/path/to/spec.rb`
3. Use `just check` before committing (linting + security)
   - Note: First run after modifying files may fail with "files were modified by this hook" - run again
4. Always use Rails generators for migrations and models
5. Follow conventional commits for git messages
6. Keep PRs focused and small
7. Verify logs are helpful for debugging and don't contain sensitive data
8. Ensure log volume is reasonable (not too verbose)

### Docker Development

**Docker Configuration Files:**

- `docker/nginx/nginx.conf` - Nginx reverse proxy config for production load balancing
- Production uses nginx in front of horizontally-scaled web replicas (see `docker-compose-production.yml`)
- Scale web replicas via CLI: `--scale web=N` or `just docker-prod-scale N`
- Scaling formula: n+1 replicas where n = number of active cracking nodes

```bash
# Start development environment
docker compose up --watch

# Start production environment
docker compose -f docker-compose-production.yml up

# Scale production web replicas (n+1 where n=active nodes)
just docker-prod-scale 9

# Check production service status
just docker-prod-status

# View nginx / web logs
just docker-prod-logs-nginx
just docker-prod-logs-web

# Shell into Rails container
just docker-shell

# PostgreSQL service is named 'postgres-db' not 'db'
docker compose up -d postgres-db

# Run tests with Docker PostgreSQL (credentials: root/password)
# Docker PG binds to IPv6 (*:5432) — use `localhost` not `127.0.0.1`
TEST_DATABASE_URL=postgres://root:password@localhost:5432/cipher_swarm_test bundle exec rspec
```

**Docker Temp Storage and Uploads:**

- Both `docker-compose.yml` and `docker-compose-production.yml` mount `tmpfs` at `/tmp` and `/rails/tmp` on web and sidekiq services — these prevent overlay filesystem exhaustion
- tmpfs sizes are configurable via `TMPFS_TMP_SIZE` (default: `1g` dev, `512m` prod) and `TMPFS_RAILS_TMP_SIZE` (default: `256m`) environment variables
- Active Storage `blob.open` downloads to `/tmp` (OS temp), not `/rails/tmp` (Rails app temp) — the Dockerfile does not set `TMPDIR`
- `/rails/tmp` holds Bootsnap cache (~27 MB) — small but accumulates on constrained overlays over time
- Nginx has `client_max_body_size 0` (unlimited) and `proxy_request_buffering off` for Active Storage direct uploads
- Thruster has been removed — Puma serves directly on port 80, nginx handles HTTP/2/compression/caching
- `TempStorageValidation` concern on `ProcessHashListJob`, `CountFileLinesJob`, `CalculateMaskComplexityJob` checks available `/tmp` space before downloading
- `InsufficientTempStorageError` retries 5 times with polynomial backoff, then discards with structured `[TempStorage]` log message
- See `docs/deployment/docker-storage-and-tmp.md` for tmpfs sizing guidance
- See GOTCHAS.md § Infrastructure for the full set of temp storage and upload gotchas

**Environment Files:**

- `.env` - Contains secrets (gitignored, not committed)
- `.envrc` - Environment isolation config (committed to repo)
- `.envrc` auto-loads via direnv when entering directory

### Administrate Dashboard Patterns

- Association field names must match model exactly: `has_many :project_users` → `project_users: Field::HasMany`
- `Field::Select` with `.pluralize` pattern assumes Rails enums - doesn't work with Rolify roles
- Dashboard files: `app/dashboards/*_dashboard.rb`

### Mergify Merge Queue

- `.mergify.yml` manages merge automation — squash merge, conventional commit enforcement
- Human PRs: manually enqueued via `/queue` comment (repo permissions restrict to maintainers)
- Bot PRs (dependabot, dosubot): autoqueued, no label gates
- Merge protections (CI checks, conventional commits, staleness) apply to all PRs regardless of queue method
- Dependabot exempt from conventional commit check (uses "Bump ..." titles)
- `MERGIFY_TOKEN` secret required for CI Insights upload; guarded for forks where secrets are unavailable
- Dependabot `rebase-strategy: "disabled"` on all ecosystems — Mergify handles branch updates

**GitHub Issue Priority Labels:**

- Use only `priority:critical`, `priority:high`, `priority:medium`, `priority:low` (no spaces, no alternative formats)

### Storage Backend (ActiveStorage)

- Default storage is local disk (`ACTIVE_STORAGE_SERVICE=local`), shared via Docker volume
- S3-compatible storage (AWS S3, MinIO, SeaweedFS) is opt-in: set `ACTIVE_STORAGE_SERVICE=s3` plus `AWS_*` env vars
- Application code is storage-agnostic via ActiveStorage — no backend-specific APIs used
- `config/storage.yml` defines `:local`, `:test`, and `:s3` services
- Health check (`SystemHealthCheckService#check_storage`) works with any backend via `ActiveStorage::Blob.service.exist?`
- **Migration rake task**: `bin/rails storage:migrate_to_local` migrates files from S3/MinIO to local disk
  - Supports `DRY_RUN=true` for preview and `SOURCE_SERVICE=<name>` to override the download service
  - Idempotent, checksum-verified, interruptible — see `docs/deployment/air-gapped-deployment.md`

### Resources

- V2 Upgrade Overview: docs/v2-upgrade-overview.md
- System Tests Guide: docs/testing/system-tests-guide.md
- Logging Guide: docs/development/logging-guide.md
- API Documentation: /api-docs (when server running)
- Justfile Documentation: .kiro/steering/justfile.md

## Agent Rules <!-- tessl-managed -->

@.tessl/RULES.md follow the [instructions](.tessl/RULES.md)
