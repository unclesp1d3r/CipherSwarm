# AGENTS.md

This file provides guidance to Agents when working with code in this repository.

## Project Overview

CipherSwarm is a distributed hash cracking system built on Rails 8.0+ inspired by Hashtopolis. It manages hash-cracking tasks across multiple agents using a web-based interface with real-time capabilities via Hotwire.

**Current Status**: Undergoing V2 upgrade (see docs/v2-upgrade-overview.md)

## Development Tools

This project uses [mise](https://mise.jdx.dev/) for development tool version management. All tool versions are defined in `.mise.toml`:

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
```

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

- pending → active → benchmarked → error/stopped
- Transitions: activate, benchmarked, error, stop

**Attack States:**

- pending → running → completed/exhausted/failed/paused
- Transitions: run, pause, resume, complete, exhaust, fail

**Task States:**

- pending → running → completed/exhausted/failed/paused
- Transitions: accept, run, complete, pause, resume, error, exhaust, cancel, abandon
- Tasks track progress via associated HashcatStatus records

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
   bun test:js
   ```

Both unit tests for Stimulus controllers and integration tests via system tests are included in the project.

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

### Code Organization Standards

From .cursor/rules/core-principals.mdc and rails.mdc:

**File Structure:**

- Business logic: app/models/ (no app/services/ directory)
- API endpoints: app/controllers/api/v1/
- View components: app/components/
- Custom validations: app/validators/
- Background jobs: app/jobs/

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

**Migration Generation:**

- ALWAYS use Rails generators for migrations
- Never create migration files manually
- Use `bin/rails generate migration` or `just db-migration`

### Important Configuration Files

- **justfile** - Task runner with common commands (see `just --list`)
- **Procfile.dev** - Development processes (web, CSS, JS)
- **.rubocop.yml** - RuboCop configuration (inherits from rubocop-rails-omakase)
- **config/routes.rb** - Routes organized with `draw(:admin)`, `draw(:client_api)`, `draw(:errors)`, `draw(:devise)`
- **swagger_helper.rb** - OpenAPI/Swagger configuration

### Common Patterns

**Nested Resources:**

- Attacks are nested under Campaigns: `/campaigns/:campaign_id/attacks`
- Create attacks via `new_campaign_attack_path(campaign)`

**Priority-Based Execution:**

- Campaign priority enum: deferred (-1) → flash_override (5)
- Higher priority campaigns automatically pause lower priority ones
- Callback `pause_lower_priority_campaigns` in Campaign model

**Agent Task Assignment:**

- Agents request tasks via `GET /api/v1/client/tasks/new`
- Tasks claimed with `claimed_by_agent_id` and `expires_at`
- Agents submit status updates via `POST /api/v1/client/tasks/:id/submit_status`
- Agents submit cracks via `POST /api/v1/client/tasks/:id/submit_crack`

**Authorization Flow:**

- CanCanCan abilities defined in app/models/ability.rb
- `authorize!` in controllers
- Project-based scoping for all resources
- Admin users have unrestricted access

**Logging Patterns:**

- Use structured logging with `[LogType]` prefixes (`[APIRequest]`, `[APIError]`, `[AgentLifecycle]`, `[BroadcastError]`)
- Include relevant context (IDs, timestamps, state changes)
- Log errors with backtrace (first 5 lines)
- Ensure logging failures don't break application (rescue blocks)
- Always test that important events are logged correctly
- Verify sensitive data is filtered (see docs/development/logging-guide.md)

### Development Workflow

1. Use `just dev` to start the development server (Rails + assets + Sidekiq)
2. Run tests frequently with `just test` or `just test-file spec/path/to/spec.rb`
3. Use `just check` before committing (linting + security)
4. Always use Rails generators for migrations and models
5. Follow conventional commits for git messages
6. Keep PRs focused and small
7. Verify logs are helpful for debugging and don't contain sensitive data
8. Ensure log volume is reasonable (not too verbose)

### Docker Development

```bash
# Start development environment
docker compose up --watch

# Start production environment
docker compose -f docker-compose-production.yml up

# Shell into Rails container
just docker-shell
```

### Resources

- V2 Upgrade Overview: docs/v2-upgrade-overview.md
- System Tests Guide: docs/testing/system-tests-guide.md
- Logging Guide: docs/development/logging-guide.md
- API Documentation: /api-docs (when server running)
- Justfile Documentation: .kiro/steering/justfile.md
