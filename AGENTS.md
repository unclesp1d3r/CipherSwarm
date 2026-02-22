# AGENTS.md

This file provides guidance to Agents when working with code in this repository.

## Project Overview

CipherSwarm is a distributed hash cracking system built on Rails 8.0+ inspired by Hashtopolis. It manages hash-cracking tasks across multiple agents using a web-based interface with real-time capabilities via Hotwire.

**Current Status**: Undergoing V2 upgrade (see docs/v2-upgrade-overview.md)

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
TEST_DATABASE_URL=postgres://root:password@127.0.0.1:5432/cipher_swarm_test bundle exec rspec
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
   - Priority-based execution model (deferred → routine → priority → urgent → immediate → flash → flash_override)
   - Higher priority campaigns pause all lower priority campaigns
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
- Devise 5 applies `downcase_first` to humanized authentication keys in flash messages ("name" instead of "Name") — test page objects should derive labels dynamically via `User.human_attribute_name(key).downcase_first` (see `spec/support/page_objects/sign_in_page.rb#devise_auth_keys_label`)
- CanCanCan for authorization (see app/models/ability.rb)
- Rolify for role management

**Agent API:**

- Bearer token authentication (24-character secure tokens)
- Tokens generated on Agent creation, stored in `agents.token`
- API endpoints at `/api/v1/client/*` (JSON only)
- Authentication flow: Agent authenticates → receives configuration → processes tasks

### Project-Based Multi-Tenancy

- Projects provide resource isolation and access control
- Agents can be assigned to specific Projects or work across all Projects
- Users have Project-specific roles (managed via ProjectUser join model)
- Resources (hash lists, campaigns, attacks) scoped to Projects

### State Machines

Three core models use state_machines-activerecord:

**Agent States:**

- States: pending, active, stopped, error, offline
- Transitions: activate, benchmarked (pending→active), deactivate, shutdown, check_online, check_benchmark_age, heartbeat

**Attack States:**

- pending → running → completed/exhausted/failed/paused
- Transitions: run, pause, resume, complete, exhaust, fail

**Attack Scope Gotcha:**

- `Attack.incomplete` excludes `:running` and `:paused` (only matches pending/failed) — use `without_states(:completed, :exhausted)` when you need all unfinished work including running attacks

**Task States:**

- pending → running → completed/exhausted/failed/paused
- Transitions: accept, run, complete, pause, resume, error, exhaust, cancel, abandon
- Tasks track progress via associated HashcatStatus records

**Task State Machine Gotchas:**

- `task.abandon` triggers `attack.abandon` which destroys ALL tasks for that attack
- For reassigning running tasks, use `pause` then `resume` instead of `abandon`
- The `retry` event already handles incrementing `retry_count` and clearing `last_error`
- `accept` only transitions from `pending` or `running` — orphaned paused tasks must be `resume!`d to `pending` before a new agent can accept them
- `resume!` marks the task as `stale: true`, ensuring the new agent re-downloads crack data
- `accept_status` only allows transitions from active states (pending/running → running, paused → same) — finished states (completed/exhausted/failed) are blocked to prevent task resurrection

### Service Layer Pattern

Business logic is extracted into service objects and models:

- Controllers are kept thin (authorization, params, response)
- Complex operations live in model methods (not separate service objects currently)
- Background jobs in app/jobs/ handle async operations:
  - `ProcessHashListJob` - Process uploaded hash lists
  - `CalculateMaskComplexityJob` - Calculate mask complexity
  - `CountFileLinesJob` - Count lines in uploaded files
  - `UpdateStatusJob` - Update task status

### File Storage

- Active Storage for file uploads (hash lists, word lists, rule lists, mask lists)
- AWS S3 for production storage
- Local disk storage for development
- File validation via ActiveStorageValidations gem

### Pagy 43 Pagination Rendering

- All paginated views must use `<%== @pagy.series_nav(:bootstrap) %>` with a `<noscript><%== @pagy.series_nav %></noscript>` fallback
- Some views use a local `pagy` variable (from partials) instead of `@pagy` — same API applies
- Guard both `series_nav` and `<noscript>` inside `if pagy.pages > 1` (see `campaigns/_error_log.html.erb` for reference)
- `Railsboot::PaginationComponent` wraps `series_nav(:bootstrap)` with noscript fallback for reuse in view components

### Real-Time Features

- Hotwire (Turbo + Stimulus) for interactive UI
- Turbo Streams for real-time updates
- `broadcasts_refreshes` on models to push updates to clients
- Solid Cable for WebSocket connections

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
- Custom ruleset in `vacuum-ruleset.yaml` disables rules that conflict with Rails conventions (snake_case properties, underscore paths, description duplication, `$ref` siblings from rswag description placement)
- Use `request_body_json schema: {...}, examples: :let_name` for request bodies (polyfilled in spec/support/rswag_polyfills.rb for rswag 3.0.0.pre)
- `request_body_json` must be called **inside** the HTTP method block (`post`, `put`, etc.), not at the path level

**rswag 3.0.0.pre Migration Notes:**

- `openapi_strict_schema_validation` removed in 3.x — replaced by `openapi_no_additional_properties` and `openapi_all_properties_required`
- `request_body_json` does not exist in rswag 3.0.0.pre — polyfilled in `spec/support/rswag_polyfills.rb`
- `RequestFactory` in 3.x resolves parameters via `params.fetch(name)` against `example.request_params` (empty hash by default); since rswag 2.x resolved parameters via `example.send(param_name)` directly from `let` blocks, `LetFallbackHash` in `spec/support/rswag_polyfills.rb` bridges this gap by falling back to `example.public_send(key)` when `request_params` lacks the key
- The rswag 3.x formatter already converts internal `in: :body` + `consumes` to OAS 3.0 `requestBody` — polyfills use this mechanism
- Known limitation: rswag 3.0.0.pre places `description` inside `requestBody.content.schema` rather than at the `requestBody` level — this is less conventional in OpenAPI 3.0 but does not affect functionality
- rswag 3.0.0.pre is the only version with proper OpenAPI 3.0 `requestBody` generation; 2.17.0 (latest stable, Nov 2025) only added Rails 8.1 gemspec support and still has the `in: body` limitation

#### JavaScript Testing

To set up JavaScript testing in the project, we use Vitest. Follow the steps below:

1. Install Vitest and dependencies:

   ```bash
   bun add -D vitest jsdom @testing-library/dom @hotwired/stimulus
   ```

2. Create a Vitest configuration file `vitest.config.js` in the project root:

   ```javascript
   import {
       defineConfig
   } from 'vitest/config';
   export default defineConfig({
       test: {
           environment: 'jsdom',
       },
   });
   ```

3. Create a test setup file `spec/javascript/setup.js` to initialize Stimulus Application for tests.

4. Run tests using:

   ```bash
   just test-js
   # or directly:
   npx vitest run
   ```

Both unit tests for Stimulus controllers and integration tests via system tests are included in the project.

- Pagy JS is distributed via the gem's `javascripts/` directory, not npm — `config/initializers/pagy.rb` adds it to asset paths and esbuild resolves via `NODE_PATH`

**Vitest Mock Patterns:**

- `bun test` uses Bun's runner (no jsdom) — always use `just test-js` or `npx vitest run` for Vitest
- `vi.mock` is hoisted to file top; use `vi.hoisted()` for mock references: `const { mockFn } = vi.hoisted(() => ({ mockFn: vi.fn() }))`
- Turbo/Stimulus mocks: mock `@hotwired/turbo` and `@hotwired/stimulus` modules, not individual imports

## Testing Strategy

**System Tests (spec/system/):**

- Page Object Pattern (page objects in spec/support/page_objects/)
- Capybara + Selenium WebDriver with Chrome
- Screenshots on failure (tmp/capybara/)
- Key workflows: authentication, agent management, campaigns, file uploads, authorization
- See docs/testing/system-tests-guide.md

**CI Test Scope:**

- GitHub CI excludes `spec/system/` via `--exclude-pattern` — system tests only run locally via `just ci-check`
- `continue-on-error: true` on CI test step for Mergify quarantine features
- JUnit XML: `rspec_junit_formatter` outputs `<testsuite>` (singular); Mergify CI Insights requires `<testsuites>` (plural) — a CI step wraps it
- Tests with font-loading (e.g., Bootstrap icons) can hang in headless Chrome - skip with `skip: ENV["CI"].present?`
- Selenium requires explicit Chrome binary path: `options.binary = ENV["CHROME_BIN"]` in `spec/support/capybara.rb`
- File downloads don't work in CI headless Chrome; test download content via request specs instead
- `ProcessHashListJob` can race against DB truncation cleanup causing intermittent `PG::ForeignKeyViolation` on `hash_items` — safe to re-run

**Turbo Stream System Test Pattern:**

- Turbo Stream partial replacements do NOT trigger flash messages or update elements outside the replaced partial
- Do NOT wait for flash messages or CSS badges after Turbo Stream actions (cancel, retry, reassign)
- Use `sleep 1` + direct DB verification: `task.reload; expect(task.state).to eq("pending")`
- Bootstrap toasts: use `have_css(".toast-body", text: "...", visible: :all, wait: 5)` — the `.toast` wrapper has no visible text content
- Task actions use granular Turbo Streams (`turbo_stream.update`/`replace` with named DOM IDs like `task-details-{id}`, `task-actions-{id}`, `task-error-{id}`), not model-based replacement
- To verify button removal after Turbo actions, reload the page with `visit task_path(task)` then assert

**Turbo Frame Targeting:**

- Do NOT wrap entire show page content in a single `turbo_frame_tag dom_id(@model)` — causes all sections to be replaced when any Turbo Stream targets the model
- Use granular named frames/divs for updateable sections: `turbo_frame_tag "task-details-#{@task.id}"`, `div id="task-actions-#{@task.id}"`
- Partials rendered via Turbo Stream should NOT contain their own `turbo_frame_tag` — let the show page control framing
- Use `turbo_stream.update` for turbo-frame targets (preserves frame element); use `turbo_stream.replace` for div targets (partial must include wrapper div with same ID)

**Health Check Test Setup:**

- Specs touching `SystemHealthCheckService` require Redis lock cleanup in `before`: `Sidekiq.redis { |conn| conn.del(SystemHealthCheckService::LOCK_KEY) }`
- Also need stubs for DB, storage, and Sidekiq — extract a `stub_health_checks` private method (see `spec/requests/system_health_spec.rb` for canonical example)

**Model Tests (spec/models/):**

- FactoryBot factories (spec/factories/)
- Comprehensive validation and association testing
- State machine transition testing

**State Machine Testing:**

- `transition any => same` always succeeds unless the save fails
- To test failure paths: invalidate the model via `update_column` (bypassing validations) so save fails during transition
- Beware DB NOT NULL constraints - use columns with only Rails-level validations (e.g., `workload_profile` numericality)

**Deterministic Ordering:**

- When using `min_by`, `sort_by`, or `ORDER BY` with columns that can tie, always add a tiebreaker (typically `.id`)
- Example: `tasks.min_by { |t| [t.priority, t.progress, t.id] }` — without `t.id`, CI may return different results than local

**Database Deadlock in Tests:**

- `DatabaseCleaner.clean_with(:truncation)` can deadlock if concurrent PG connections exist
- Retry the test command — deadlocks are transient and resolve on second run
- Some tests fail intermittently in full suite but pass in isolation — use `git stash` to verify if failures are pre-existing vs introduced

**Cache Key Testing:**

- `touch` may not change `updated_at` within the same second — use `update_column(:updated_at, 1.minute.from_now)` to force cache key changes in tests
- CampaignEtaCalculator cache keys include `attacks.maximum(:updated_at)` and `tasks.maximum(:updated_at)` — both must change to bust cache

**Hash Item Test Setup:**

- When testing "no uncracked hashes" scenarios, call `hash_list.hash_items.delete_all` before creating test hash_items — factories or callbacks may create default items

**DB Constraint Testing:**

- Use `record.delete` (not `destroy`) when testing DB-level FK cascades — `destroy` fires Rails callbacks that mask missing constraints

**Request Tests (spec/requests/):**

- API endpoint testing
- Turbo Stream error rescue in controllers with `rescue_from StandardError` causes `ActionController::RespondToMismatchError` (double `respond_to`) — test with `expect { post ... }.to raise_error(ActionController::RespondToMismatchError)`
- Generates Swagger documentation via RSwag
- Authentication and authorization testing
- When service methods add new SQL queries, stubs like `allow(...).to receive(:execute).with("SELECT 1")` reject other queries — add `and_call_original` as default first

**Non-Standard Spec Directories:**

- `spec/performance/` - Page load benchmarks and query count efficiency tests
- `spec/deployment/` - Air-gapped deployment validation (CDN-free assets, Docker config, offline readiness)
- `spec/coverage/` - Coverage verification (validates spec file existence across layers)
- These use `# rubocop:disable RSpec/DescribeClass` since they describe behaviors, not classes

**Logging Tests:**

- Structured log output verification
- Rails.logger mocking to verify log messages
- Sensitive data filtering verification
- Error handling without breaking application flow
- Test that logs include relevant context (IDs, timestamps, state changes)
- See docs/development/logging-guide.md for logging patterns

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

**Ruby 3.4+ Dependencies:**

- `csv` gem must be in Gemfile (removed from Ruby stdlib in 3.4)
- Add `gem "csv", "~> 3.3"` if generating CSV files

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

- Business logic: app/models/ and app/services/ (6 service objects)
- API endpoints: app/controllers/api/v1/
- View components: app/components/
- Custom validations: app/validators/
- Background jobs: app/jobs/

**Documentation Indexes:**

- When adding new files to `docs/user-guide/`, update BOTH `docs/user-guide/README.md` (user guide index) AND `docs/README.md` (top-level docs index) with links to the new files
- `docs/user-guide/README.md` includes a "What's New in V2" section and a Quick Navigation table that also need updating for new features
- When adding new files to `docs/deployment/`, update `docs/README.md` with links to the new files
- `docs/deployment/air-gapped-deployment.md` is the DevOps-focused guide; `docs/user-guide/air-gapped-deployment.md` is the user-focused version with the 10-item validation checklist

**Ruby Style:**

- Target Ruby 3.2+, frozen string literals
- 120 character line length, 2 space indentation
- Methods in alphabetical order (except initialize, CRUD actions)
- Maximum 4 parameters per method
- Use RuboCop with Rails Omakase configuration

**Testing Standards:**

- Maximum 20 lines per RSpec example
- Maximum 5 expectations per example
- Use FactoryBot factories, not fixtures
- Test both happy and edge cases
- For ActiveJob::DeserializationError tests, use `instance_double` instead of instantiating (constructor signature varies)

**ViewComponent Testing:**

- When components query database (e.g., compatible agents), tests must create that data
- Use `create(:factory)` in tests before `render_inline` to ensure conditional UI renders

**Migration Generation:**

- ALWAYS use Rails generators for migrations
- Never create migration files manually
- Use `bin/rails generate migration` or `just db-migration`
- **Why this is critical:** Running `db:migrate` regenerates `schema.rb` from actual DATABASE state, not from migrations
- Manual migration creation causes schema drift: unrelated DB changes get committed
- Schema drift example: Local DB has dropped tables → manual migration → `db:migrate` → schema.rb shows deletions

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

### Common Patterns

**Nested Resources:**

- Attacks are nested under Campaigns: `/campaigns/:campaign_id/attacks`
- Create attacks via `new_campaign_attack_path(campaign)`

**Priority-Based Execution:**

- Campaign priority enum: deferred (-1) → flash_override (5)
- Higher priority campaigns automatically pause lower priority ones
- Callback `pause_lower_priority_campaigns` in Campaign model

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
- **`tasks.agent_id` is NOT NULL** — never set to nil. On agent shutdown, tasks are paused and claim fields (`claimed_by_agent_id`, `claimed_at`, `expires_at`) are cleared. `TaskAssignmentService#find_unassigned_paused_task` detects orphans by checking the owning agent's state (offline/stopped), then reassigns `agent_id` and calls `resume!` on pickup.
- Agents submit status updates via `POST /api/v1/client/tasks/:id/submit_status`
- Agents submit cracks via `POST /api/v1/client/tasks/:id/submit_crack`

**Authorization Flow:**

- CanCanCan abilities defined in app/models/ability.rb
- `authorize!` in controllers
- Project-based scoping for all resources
- Admin users have unrestricted access

**CanCanCan Nested Associations:**

- Task abilities use: `attack: { campaign: { project_id: user.all_project_ids } }`
- Association path follows model relationships: Task → attack → campaign → project
- Wrong path order will silently fail authorization checks

**Nullable Parameters:**

- Use `params.key?(:field)` to check if parameter exists (even if nil)
- Use `params[:field].present?` to check for non-nil values only
- Important for API endpoints that need to distinguish between missing vs null values

**Redis Lock Patterns:**

- `conn.set(key, value, nx: true)` returns `true` on success, `nil` on contention (not `false`) — never use `rescue => nil` around lock acquisition, as it makes contention indistinguishable from Redis failure
- Always capture lock errors in a separate variable (`lock_error`) to distinguish "lock contended" from "Redis down"
- See `SystemHealthCheckService#call` for the canonical lock-with-error-capture pattern

**Logging Patterns:**

- Use structured logging with `[LogType]` prefixes (`[APIRequest]`, `[APIError]`, `[AgentLifecycle]`, `[BroadcastError]`, `[AttackAbandon]`, `[JobDiscarded]`)
- `Rails.logger.debug { block }` (block-form) cannot be tested with `have_received(:debug).with(/pattern/)` — use block-capture: `debug_messages = []; allow(Rails.logger).to receive(:debug) { |*args, &block| debug_messages << (block ? block.call : args.first) }; expect(debug_messages).to include(match(/pattern/))`
- Include relevant context (IDs, timestamps, state changes)
- Log errors with backtrace (first 5 lines)
- Ensure logging failures don't break application (rescue blocks)
- Always test that important events are logged correctly
- Verify sensitive data is filtered (see docs/development/logging-guide.md)

**Database Transactions:**

- Wrap related operations in `Model.transaction do ... end` when they must succeed/fail together
- Use `save!` (bang) inside transactions to trigger rollback on failure
- Handle `ActiveRecord::RecordInvalid` outside the transaction block

**Foreign Key Cascade Strategy:**

- Prefer DB-level `on_delete: :cascade` / `:nullify` over relying solely on Rails `dependent:` callbacks
- `delete_all` and DB-level cascades bypass Rails callbacks — without DB rules, orphans or FK violations result
- Ephemeral child tables (telemetry, statuses) should cascade with their parent
- When a table has multiple FKs to the same parent, always specify `column:` explicitly in `remove_foreign_key`/`add_foreign_key`
- Test DB cascades with `delete` (not `destroy`) to verify the FK constraint, not Rails callbacks

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

**PreToolUse Hook:**

- A PreToolUse hook protects certain files (migrations, etc.) from direct Read/Edit/Write tools
- Always try Read/Edit/Write tools first
- If blocked, use bash commands as fallback for that specific file only
- Never default to bash for file operations without first attempting proper tools

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
TEST_DATABASE_URL=postgres://root:password@127.0.0.1:5432/cipher_swarm_test bundle exec rspec
```

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
- Dependabot exempt from conventional commit check (uses "Bump ..." titles)
- `MERGIFY_TOKEN` secret required for CI Insights upload; guarded for forks where secrets are unavailable
- Dependabot `rebase-strategy: "disabled"` on all ecosystems — Mergify handles branch updates

### Storage Backend (ActiveStorage)

- Application code is storage-agnostic via ActiveStorage — no MinIO-specific APIs used
- Switching storage backends (local disk, SeaweedFS, S3) requires only config/docker changes
- See issue #577 for MinIO replacement tracking

### Resources

- V2 Upgrade Overview: docs/v2-upgrade-overview.md
- System Tests Guide: docs/testing/system-tests-guide.md
- Logging Guide: docs/development/logging-guide.md
- API Documentation: /api-docs (when server running)
- Justfile Documentation: .kiro/steering/justfile.md
