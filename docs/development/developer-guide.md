# CipherSwarm Developer Guide

Welcome to the CipherSwarm development team! This guide will help you understand the codebase architecture, development workflows, and best practices.

---

## Table of Contents

01. [Quick Start](#quick-start)
02. [Architecture Overview](#architecture-overview)
03. [Domain Model](#domain-model)
04. [Code Organization](#code-organization)
05. [Development Patterns](#development-patterns)
06. [Testing Strategy](#testing-strategy)
07. [API Development](#api-development)
08. [Environment Variables](#environment-variables)
09. [Security Best Practices](#security-best-practices)
10. [Background Jobs](#background-jobs)
11. [Real-Time Features](#real-time-features)
12. [Database Conventions](#database-conventions)
13. [Common Tasks](#common-tasks)
14. [Common Gotchas](#common-gotchas)

---

## Quick Start

### Prerequisites

Install [mise](https://mise.jdx.dev/) for tool version management:

```bash
# macOS
brew install mise

# Linux
curl https://mise.run | sh

# Install project tools
cd /path/to/CipherSwarm
mise install
```

### First-Time Setup

```bash
# Clone repository
git clone https://github.com/unclesp1d3r/CipherSwarm.git
cd CipherSwarm

# Install dependencies
just setup

# Start development server
just dev
```

The application will be available at `http://localhost:3000`.

**Note:** File upload system tests automatically start tusd via testcontainers — no manual setup required.

### Development Services

| Service    | URL                            | Description                            |
| ---------- | ------------------------------ | -------------------------------------- |
| Web App    | http://localhost:3000          | Main application                       |
| Sidekiq UI | http://localhost:3000/sidekiq  | Background job monitoring (admin only) |
| API Docs   | http://localhost:3000/api-docs | Swagger/OpenAPI documentation          |
| Admin      | http://localhost:3000/admin    | Administrate dashboard                 |

#### Testcontainers-based tusd for System Tests

System tests requiring file uploads use testcontainers to automatically start a tusd Docker container. This eliminates the need for manual Docker container management during development and testing.

- `TusdHelper.ensure_tusd_running` starts the container on a random port
- Tests that use tus uploads should include `before(:all) { TusdHelper.ensure_tusd_running }` in their setup
- The container is shared across the test suite and automatically cleaned up on process exit
- No manual configuration needed — testcontainers handles container lifecycle management

### Essential Commands

```bash
# Development
just dev          # Start all services (web, css, js, sidekiq)
just console      # Rails console

# Testing
just test                           # Run all tests with coverage
just test-file spec/models/task_spec.rb  # Run specific test file
just test-system                    # Run system tests (browser)
just test-api                       # Run API request tests

# Code Quality
just check        # Run all linters and security checks
just format       # Auto-format code
just lint         # RuboCop only
just security     # Brakeman security scan

# Database
just db-migrate   # Run migrations
just db-rollback  # Rollback last migration
just db-reset     # Reset database (drop, create, migrate, seed)
```

---

## Architecture Overview

### Technology Stack

| Layer           | Technology                                                              |
| --------------- | ----------------------------------------------------------------------- |
| Language        | Ruby 3.4.5                                                              |
| Framework       | Rails 8.0+                                                              |
| Database        | PostgreSQL 17+                                                          |
| Cache/Jobs      | Redis 7.2+ (Solid Cache, Sidekiq)                                       |
| Frontend        | Hotwire (Turbo + Stimulus), Bootstrap 5 with Catppuccin Macchiato theme |
| Typography      | Self-hosted: Space Grotesk, IBM Plex Sans, JetBrains Mono               |
| Icons           | Bootstrap Icons                                                         |
| Components      | ViewComponent                                                           |
| Authentication  | Rails 8 Auth + Devise                                                   |
| Authorization   | CanCanCan + Rolify                                                      |
| Background Jobs | Sidekiq + Sidekiq-Cron                                                  |
| API Docs        | RSwag (OpenAPI)                                                         |

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Web Browsers                            │
│                 (Turbo, Stimulus, Action Cable)              │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Rails Application                         │
├─────────────────┬─────────────────┬─────────────────────────┤
│   Web UI        │   Agent API     │   Background Jobs       │
│   Controllers   │   (JSON)        │   (Sidekiq)             │
├─────────────────┴─────────────────┴─────────────────────────┤
│                      Models & Services                       │
├─────────────────────────────────────────────────────────────┤
│   PostgreSQL    │     Redis       │   Active Storage (S3)   │
└─────────────────────────────────────────────────────────────┘
```

---

## Domain Model

### Core Hierarchy

CipherSwarm organizes work in a hierarchical structure:

```
Project (tenant boundary)
└── Campaign (work unit targeting a hash list)
    ├── HashList (target hashes)
    └── Attack (execution strategy)
        └── Task (work unit for agent)
            └── Agent (worker machine)
```

### Key Concepts

**Project**: Multi-tenant boundary. Users have roles within projects. Resources (campaigns, hash lists, agents) are scoped to projects.

**Campaign**: A cracking operation targeting a specific hash list. Contains multiple attacks with different strategies. Has priority levels that affect task scheduling.

**Attack**: Specific hashcat configuration (attack mode, wordlist, rules, mask). Gets subdivided into tasks for parallel execution.

**Task**: Smallest unit of work. Assigned to one agent. Tracks progress via HashcatStatus records.

**Agent**: Distributed worker running hashcat. Authenticates via bearer token. Reports benchmarks, progress, and results.

### State Machines

Three models use state machines (via `state_machines-activerecord`):

**Agent States**: `pending`, `active`, `stopped`, `error`, `offline` (note: `benchmarked` is an event that transitions `pending → active`, not a state)

**Attack States**: `pending → running → completed/exhausted/failed/paused`

**Task States**: `pending → running → completed/exhausted/failed/paused`

See `docs/architecture/diagrams.md` for visual state machine diagrams.

### Agent Shutdown Cascade Behavior

When an agent shuts down, it triggers a cascade of state changes:

- Running tasks are automatically paused via `pause_incomplete_attacks`
- Task claim fields (`claimed_by_agent_id`, `claimed_at`, `expires_at`) are cleared
- Tasks are marked with `paused_at` timestamp for grace period tracking
- Attacks with no remaining active (non-paused) tasks are automatically paused
- The `paused_at` timestamp enables time-based orphaned task recovery

### Task Pause/Resume with Grace Period

Tasks track pause state for efficient recovery:

- `paused_at` datetime column records when task was paused
- Orphaned task recovery uses time-based grace periods instead of agent state checks
- Agents prioritize reclaiming their own paused tasks (to leverage restore files)
- After grace period expires, any agent can claim orphaned tasks from other agents
- Resume callbacks use `update_columns` to bypass optimistic locking and avoid StaleObjectError

Example:

```ruby
after_transition on: :resume do
  update_columns(stale: true, paused_at: nil)  # Bypass locking, clear pause timestamp
end
```

---

## Code Organization

### Directory Structure

```
app/
├── channels/        # Action Cable channels
├── components/      # ViewComponent components
├── controllers/
│   ├── api/v1/      # Agent API controllers
│   │   │   └── client/  # Client-specific endpoints
│   └── concerns/    # Controller concerns (TaskErrorHandling)
├── dashboards/      # Administrate dashboards
├── errors/          # Custom operational errors (InsufficientTempStorageError, etc.)
├── helpers/         # View helpers
├── inputs/          # SimpleForm inputs
├── jobs/            # Sidekiq background jobs
│   └── concerns/    # Job concerns (TempStorageValidation, AttackPreemptionLoop)
├── mailers/         # Email templates
├── models/
│   └── concerns/    # Model concerns
│       └── agent/   # Agent-specific concerns (Broadcasting, Benchmarking)
├── services/        # Service objects
├── validators/      # Custom validators
└── views/
    ├── components/  # ViewComponent templates
    └── layouts/     # Layout templates

config/
├── routes/          # Route partials (admin, client_api, devise, errors)
└── locales/         # I18n translations

spec/
├── factories/       # FactoryBot factories
├── models/          # Model specs
├── requests/        # API request specs (RSwag)
├── support/
│   └── page_objects/ # System test page objects
└── system/          # System/integration tests
```

### File Naming Conventions

| Type       | Convention              | Example                                    |
| ---------- | ----------------------- | ------------------------------------------ |
| Model      | Singular, snake_case    | `app/models/hash_item.rb`                  |
| Controller | Plural, snake_case      | `app/controllers/campaigns_controller.rb`  |
| Service    | Action + Service        | `app/services/task_assignment_service.rb`  |
| Job        | Action + Job            | `app/jobs/process_hash_list_job.rb`        |
| Component  | Description + Component | `app/components/agent_status_component.rb` |
| Spec       | Mirror + \_spec.rb      | `spec/models/hash_item_spec.rb`            |

---

## Development Patterns

### Frontend Development

**Views**: Use plain ERB templates with Bootstrap 5 utility classes. No component abstraction layer.

**Theming**: Catppuccin Macchiato theme implemented via SCSS variable overrides:

- `_catppuccin.scss` defines the full palette and overrides Bootstrap variables (imported BEFORE `@import "bootstrap"`)
- Primary accent: `$ctp-violet: #a855f7` (DarkViolet lightened for dark-mode contrast)
- Surface hierarchy: Crust (navbar) → Mantle (sidebar) → Base (body) → Surface0 (cards, inputs)
- Component-level dark theme overrides in `application.bootstrap.scss` via `[data-bs-theme="dark"]` selector
- Available color variables: `$ctp-violet`, `$ctp-surface0`, `$ctp-text`, `$ctp-overlay0`, etc.

**Typography**: Self-hosted fonts via `@fontsource` packages (air-gap safe):

- Space Grotesk (variable, 300–700) — headings
- IBM Plex Sans (400, 500, 600, 700) — body text
- JetBrains Mono (variable, 100–800) — monospace for hashes/masks
- Font files copied to `app/assets/builds/` by `build:css:fonts` script

**ViewComponent**: Use for reusable logic, but render Bootstrap markup directly (no abstraction layer):

```ruby
# Good - ViewComponent with plain Bootstrap HTML
class AgentStatusComponent < ViewComponent::Base
  def initialize(agent:)
    @agent = agent
  end

  def badge_class
    case @agent.state
    when "active" then "badge bg-success"
    when "error" then "badge bg-danger"
    else "badge bg-secondary"
    end
  end
end

# View template uses Bootstrap HTML
<span class="<%= badge_class %>">
  <%= @agent.state.titleize %>
</span>
```

**CSS Patterns**:

- Empty states: use `.empty-state-icon` class (not inline `style="font-size: 64px;"`)
- Skeleton loaders: use `.skeleton-progress`, `.skeleton-avatar` classes
- Reference Catppuccin color hierarchy in custom styles

**Accessibility**: All new UI must meet WCAG 2.1 AA standards:

- Skip link targeting `#main-content` (already present in layout)
- Interactive elements use semantic HTML (`<button>`, not `<a href="#">`)
- All navigation landmarks have `aria-label` attributes
- Keyboard navigation support (arrow keys for tabs, focus management)
- Semantic color classes (`text-body-secondary`, not `text-muted`)

### Service Objects

Extract complex business logic into service objects when:

- Logic spans multiple models
- Method exceeds 20 lines
- Algorithm is complex (O(n²) or worse)

**Example Structure**:

```ruby
# app/services/task_assignment_service.rb
# frozen_string_literal: true

# REASONING:
# Why: Task assignment involves complex queries across multiple models
# Alternatives: Could use model callbacks, but they're harder to test
# Performance: Queries are optimized with eager loading
class TaskAssignmentService
  def initialize(agent)
    @agent = agent
  end

  def find_available_task
    return nil unless @agent.can_accept_tasks?

    available_attacks.each do |attack|
      task = create_task_for_attack(attack)
      return task if task
    end

    nil
  end

  private

  def available_attacks
    Attack.incomplete
          .joins(campaign: { hash_list: :hash_type })
          .where(campaigns: { project_id: @agent.project_ids })
          .where(hash_lists: { hash_type_id: allowed_hash_type_ids })
          .order("campaigns.priority DESC, attacks.complexity_value")
  end

  def allowed_hash_type_ids
    @agent.hashcat_benchmarks.pluck(:hash_type_id)
  end

  def create_task_for_attack(attack)
    Task.create(attack: attack, agent: @agent)
  rescue ActiveRecord::RecordInvalid
    nil
  end
end
```

### Model Concerns

Use concerns for shared behavior across models:

```ruby
# app/models/concerns/safe_broadcasting.rb
# frozen_string_literal: true

# REASONING:
# Why: Multiple models need resilient broadcasting that doesn't break on errors
# Alternatives: Individual rescue blocks in each model
# Decision: Concern provides DRY solution with consistent error handling
module SafeBroadcasting
  extend ActiveSupport::Concern

  included do
    after_commit :safe_broadcast_refresh, unless: -> { Rails.env.test? }
  end

  private

  def safe_broadcast_refresh
    broadcast_refresh
  rescue StandardError => e
    Rails.logger.error("[BroadcastError] #{self.class}##{id}: #{e.message}")
  end
end
```

**Agent-Specific Concerns**: The Agent model uses namespaced concerns for focused behavioral units:

- `Agent::Broadcasting` - Turbo Stream broadcast methods for real-time UI updates (index cards, detail tabs)
- `Agent::Benchmarking` - Benchmark calculation and hashcat performance metrics

Both concerns follow the same pattern: REASONING blocks explaining extraction rationale, YARD documentation, and isolation of cohesive method groups to reduce model size.

**Job Concerns**: Use concerns for reusable job behavior. Example: `TempStorageValidation` (see [Background Jobs](#background-jobs) section) provides pre-download space validation for jobs that process uploaded files.

**Controller Concerns**: Use concerns for cross-cutting controller behavior. Example: `TaskErrorHandling` (see [Logging Conventions](#logging-conventions) section) provides structured logging helpers for API error handling.

### Controller Patterns

Keep controllers thin - authorization, params, response only:

```ruby
# app/controllers/campaigns_controller.rb
# frozen_string_literal: true

class CampaignsController < ApplicationController
  before_action :set_campaign, only: %i[show edit update destroy]
  load_and_authorize_resource

  def index
    @campaigns = @campaigns.includes(:hash_list, :attacks)
                           .page(params[:page])
  end

  def create
    @campaign = Campaign.new(campaign_params)
    @campaign.creator = current_user

    if @campaign.save
      redirect_to @campaign, notice: "Campaign created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(:name, :description, :priority, :hash_list_id, :project_id)
  end
end
```

### Logging Conventions

Use structured logging with consistent prefixes:

```ruby
# Good - searchable prefix, context, structured
Rails.logger.info(
  "[TaskPreemption] Preempting task #{task.id} " \
  "(priority: #{task.attack.campaign.priority}, progress: #{task.progress_percentage}%)"
)

# Good - error with backtrace
Rails.logger.error(
  "[APIError] Failed to process status: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
)

# Bad - no prefix, no context
Rails.logger.info("Task preempted")
```

**Standard Prefixes**:

- `[APIRequest]` - API request logging
- `[APIError]` - API error handling
- `[AgentLifecycle]` - Agent state changes
- `[BroadcastError]` - WebSocket broadcast failures
- `[AttackAbandon]` - Attack abandonment events
- `[JobDiscarded]` - Background job failures
- `[TaskPreemption]` - Task preemption events
- `[TaskRebalance]` - Campaign priority rebalancing events

**Structured Logging Helpers**: The `TaskErrorHandling` concern (`app/controllers/concerns/task_error_handling.rb`) provides `log_task_api_error(code, agent, task, error_messages)` for consistent `[APIError]` formatting across task state transition failures:

```ruby
# app/controllers/api/v1/client/tasks_controller.rb
unless @task.accept
  log_task_api_error("TASK_ACCEPT_FAILED", @agent, @task, @task.errors.full_messages)
  render json: { error: "Failed to accept task" }, status: :unprocessable_content
  return
end
```

---

## Testing Strategy

### Test Types

| Type      | Directory          | Purpose                                   |
| --------- | ------------------ | ----------------------------------------- |
| Model     | `spec/models/`     | Validations, associations, business logic |
| Request   | `spec/requests/`   | API endpoints, generates OpenAPI docs     |
| System    | `spec/system/`     | End-to-end browser tests                  |
| Component | `spec/components/` | ViewComponent rendering                   |
| Job       | `spec/jobs/`       | Background job behavior                   |

### Running Tests

```bash
# All tests with coverage
COVERAGE=true bundle exec rspec

# Specific file
bundle exec rspec spec/models/task_spec.rb

# Specific test
bundle exec rspec spec/models/task_spec.rb:42

# System tests with visible browser
HEADLESS=false bundle exec rspec spec/system
```

### Test Conventions

```ruby
# spec/models/task_spec.rb
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Task do
  # Use factories, not fixtures
  let(:task) { create(:task) }
  let(:agent) { create(:agent, :benchmarked) }

  # Group by behavior
  describe "validations" do
    it { is_expected.to belong_to(:attack) }
    it { is_expected.to belong_to(:agent).optional }
    it { is_expected.to validate_presence_of(:state) }
  end

  describe "state machine" do
    describe "#accept" do
      it "transitions from pending to running" do
        expect { task.accept }.to change(task, :state).from("pending").to("running")
      end
    end
  end

  # Max 20 lines per example
  # Max 5 expectations per example
end
```

### System Test Page Objects

Use page objects for system tests:

```ruby
# spec/support/page_objects/campaigns_page.rb
class CampaignsPage
  include Capybara::DSL

  def visit_index
    visit campaigns_path
    self
  end

  def create_campaign(name:, hash_list:)
    click_link "New Campaign"
    fill_in "Name", with: name
    select hash_list, from: "Hash list"
    click_button "Create Campaign"
    self
  end

  def has_campaign?(name)
    has_content?(name)
  end
end

# Usage in spec
let(:page_object) { CampaignsPage.new }

it "creates a campaign" do
  page_object.visit_index.create_campaign(name: "Test", hash_list: "NTLM Hashes")
  expect(page_object).to have_campaign("Test")
end
```

---

## API Development

### Structure

```
app/controllers/api/v1/
├── base_controller.rb      # Authentication, error handling
├── client_controller.rb    # /authenticate, /configuration
└── client/
    ├── agents_controller.rb    # /agents/:id/*
    ├── attacks_controller.rb   # /attacks/:id/*
    └── tasks_controller.rb     # /tasks/*
```

### Authentication

All API endpoints require bearer token authentication using constant-time token comparison to prevent timing attacks:

```ruby
# app/controllers/api/v1/base_controller.rb
class Api::V1::BaseController < ApplicationController
  before_action :authenticate_agent

  private

  def authenticate_agent
    authenticate_with_http_token do |token, _options|
      next if token.blank?

      candidate = Agent.find_by(token: token)
      # Constant-time comparison to prevent timing attacks on token enumeration.
      # Even when no candidate is found, compare against a dummy to equalize timing.
      dummy_token = SecureRandom.base58(24)
      compare_token = candidate&.token || dummy_token
      @agent = candidate if ActiveSupport::SecurityUtils.secure_compare(compare_token, token)
    end
    
    render_unauthorized unless @agent
  end

  def render_unauthorized
    render json: { error: "Invalid token" }, status: :unauthorized
  end
end
```

**Security Note**: Using `ActiveSupport::SecurityUtils.secure_compare` prevents timing attacks where attackers could enumerate valid tokens by measuring response times. The dummy token ensures consistent comparison timing even when no agent is found.

### Request Specs with RSwag

API tests generate OpenAPI documentation:

```ruby
# spec/requests/api/v1/client/tasks_spec.rb
require "swagger_helper"

RSpec.describe "Tasks API", type: :request do
  path "/api/v1/client/tasks/new" do
    get "Request a new task from server" do
      tags "Tasks"
      produces "application/json"
      security [bearer_auth: []]

      response "200", "new task available" do
        schema "$ref" => "#/components/schemas/Task"

        let(:Authorization) { "Bearer #{agent.token}" }
        let(:agent) { create(:agent, :benchmarked) }

        before { create(:task, :pending, attack: attack) }

        run_test!
      end

      response "204", "no new task available" do
        let(:Authorization) { "Bearer #{agent.token}" }
        let(:agent) { create(:agent, :benchmarked) }

        run_test!
      end
    end
  end
end
```

Regenerate docs: `RAILS_ENV=test rails rswag`

---

## Environment Variables

CipherSwarm uses environment variables for configuration, with different requirements for development and production environments.

### Security-Critical Variables

| Variable               | Required In | Purpose                                                                                                                                                                              |
| ---------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `TUSD_HOOK_SECRET`     | Production  | Shared secret for authenticating tusd webhook requests. Prevents cache poisoning attacks.                                                                                            |
| `POSTGRES_PASSWORD`    | Always      | Database password. Fails fast if unset to prevent insecure defaults.                                                                                                                 |
| `APPLICATION_HOST`     | Optional    | DNS rebinding protection. Set to the hostname used to access the application (e.g., "cipherswarm.lab.local"). When not set, host checking is disabled for backward compatibility.    |
| `RUN_DB_PREPARE`       | Optional    | When `true`, runs `db:prepare` on container startup. Use only in single-instance mode or one-shot migration jobs to avoid migration races across replicas.                           |
| `TMPFS_TMP_SIZE`       | Optional    | Controls tmpfs mount size at `/tmp` for Active Storage blob downloads. Default: `512m` (production), `1g` (development). See [docker-storage-and-tmp.md](docker-storage-and-tmp.md). |
| `TMPFS_RAILS_TMP_SIZE` | Optional    | Controls tmpfs mount size at `/rails/tmp` for Bootsnap cache and Rails temp files. Default: `256m`. Rarely needs tuning.                                                             |

#### tmpfs Configuration for Large Files

For deployments processing large attack resources (100 GB+ wordlists, rule files), tmpfs sizing is critical:

- **Formula**: `TMPFS_TMP_SIZE >= 1.5 × largest_attack_resource_file`
- **Memory Impact**: tmpfs counts against container memory limits. Increase `deploy.resources.limits.memory` proportionally when raising this value.
- **Alternative**: For disk-backed temp storage instead of RAM-backed tmpfs, see the TMPDIR volume approach in [docker-storage-and-tmp.md](docker-storage-and-tmp.md).

**Example:**

```bash
# Medium deployment (largest file ~1 GB)
TMPFS_TMP_SIZE=2g

# Large deployment (100 GB wordlists)
TMPFS_TMP_SIZE=150g
```

### tusd Webhook Authentication

The tusd upload service calls back to `/api/v1/hooks/tus` when uploads complete. This endpoint requires authentication via the `X-Tusd-Hook-Secret` header to prevent unauthorized cache poisoning:

```ruby
# app/controllers/api/v1/hooks/tus_controller.rb
def verify_tusd_origin
  expected = ENV.fetch("TUSD_HOOK_SECRET", nil)
  return if expected.blank? # Skip verification in dev if not configured

  provided = request.headers["X-Tusd-Hook-Secret"].to_s
  return if ActiveSupport::SecurityUtils.secure_compare(expected, provided)
  
  Rails.logger.warn("[TusHook] Unauthorized hook request from #{request.remote_ip}")
  head :unauthorized
end
```

**Production Deployment**: Ensure `TUSD_HOOK_SECRET` is set to a random value in both the Rails application and tusd configuration. In Docker deployments, this is configured via environment variables.

### DNS Rebinding Protection

Set `APPLICATION_HOST` to enable DNS rebinding attack protection in production:

```yaml
# docker-compose-production.yml
environment:
  APPLICATION_HOST: cipherswarm.lab.local
```

When set, Rails validates the `Host` header against the configured hostname. Health check endpoints (`/up`, `/api/v1/client/health`) are excluded from this check.

### Database Migration Control

In scaled deployments (multiple web replicas), run migrations as a one-shot command before starting replicas to avoid migration races:

```bash
# Run migrations once
docker compose run --rm -e RUN_DB_PREPARE=true web ./bin/rails db:prepare

# Then start replicas
docker compose up -d
```

In development or single-instance deployments, `RUN_DB_PREPARE` is not needed as migrations run automatically.

---

## Security Best Practices

### Path Traversal Protection

The `TusUploadHandler` concern includes path traversal protection to prevent file access outside allowed directories:

```ruby
def validate_source_path!(path)
  canonical_source = File.realpath(path)
  canonical_tus_dir = File.realpath(tus_uploads_dir)
  return if canonical_source.start_with?(canonical_tus_dir + "/")

  raise TusUploadError, "Path traversal attempt blocked"
end
```

This validation runs before any file operations on tusd-uploaded files.

### Webhook Authentication

All external webhook endpoints must validate requests using shared secrets:

- **tusd webhooks**: Authenticated via `TUSD_HOOK_SECRET` header
- Constant-time comparison prevents timing attacks

### Production Secret Guards

Critical secrets are enforced at startup in production:

- `TUSD_HOOK_SECRET`: Required in production (fails fast if unset)
- `POSTGRES_PASSWORD`: Required in all environments
- `APPLICATION_HOST`: Optional but recommended for DNS rebinding protection

Development environments allow running without `TUSD_HOOK_SECRET` for easier local setup.

### Nginx Security Headers

The production nginx configuration includes security headers at the reverse proxy layer:

```nginx
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=(), usb=()" always;
```

**Note**: `Strict-Transport-Security` (HSTS) should only be enabled when TLS terminates at the nginx instance. When TLS terminates upstream (e.g., cloud load balancer), the upstream proxy should set HSTS instead.

---

## Background Jobs

### Job Structure

```ruby
# app/jobs/process_hash_list_job.rb
# frozen_string_literal: true

class ProcessHashListJob < ApplicationJob
  include TempStorageValidation  # Pre-download space check for blobs

  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Handle deserialization errors (record deleted before job runs)
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.warn(
      "[JobDiscarded] ProcessHashListJob: #{error.message}"
    )
  end

  def perform(hash_list)
    ensure_temp_storage_available!(hash_list.file)  # Check before download
    HashListProcessor.new(hash_list).process
  end
end
```

**Error Handling for Resource Constraints:**

Use custom operational errors when jobs depend on external resources. `InsufficientTempStorageError` is raised by `TempStorageValidation` when `/tmp` lacks space for a blob download. `ApplicationJob` configures 5 retries with polynomial backoff, then discards with a structured log message pointing operators to sizing documentation. This prevents jobs from repeatedly failing when infrastructure is undersized for the workload.

When implementing similar resource-constrained operations:

1. Define a custom error class in `app/errors/` (e.g., `InsufficientTempStorageError`)
2. Configure retry strategy in `ApplicationJob` with `retry_on` and a discard block
3. Include clear remediation guidance in discard logs (reference deployment documentation)
4. Use concerns to encapsulate validation logic (e.g., `TempStorageValidation`)

### Queue Priorities

| Queue    | Use Case                                            |
| -------- | --------------------------------------------------- |
| default  | General background work                             |
| critical | Time-sensitive operations                           |
| high     | Priority-sensitive operations like task rebalancing |
| low      | Non-urgent batch processing                         |

### Task Preemption and Priority Rebalancing

CipherSwarm uses two mechanisms to ensure high-priority campaigns can preempt lower-priority tasks:

**Event-driven Rebalancing**: `CampaignPriorityRebalanceJob` triggers immediately when a campaign's priority is raised. This job iterates through the campaign's incomplete attacks and invokes `TaskPreemptionService` to evaluate whether any lower-priority tasks should be preempted.

```ruby
# app/jobs/campaign_priority_rebalance_job.rb
class CampaignPriorityRebalanceJob < ApplicationJob
  include AttackPreemptionLoop  # shared iteration with per-attack error isolation

  queue_as :high
  discard_on ActiveRecord::RecordNotFound

  def perform(campaign_id)
    campaign = Campaign.find(campaign_id)
    attacks = campaign.attacks.incomplete.includes(campaign: :hash_list)
    preempt_attacks(attacks)  # provided by AttackPreemptionLoop
  end
end
```

**Time-driven Rebalancing**: `UpdateStatusJob` runs periodically (via Sidekiq-Cron) to rebalance task assignments for all non-deferred (normal and high) priority campaigns. This ensures preemption logic runs even if priority changes are missed or occur during system downtime.

Enqueued by: `Campaign#trigger_priority_rebalance_if_needed` after_commit callback when priority increases.

### Scheduled Jobs

Configure in `config/initializers/sidekiq.rb`:

```ruby
Sidekiq::Cron::Job.create(
  name: "Clean stale tasks - every hour",
  cron: "0 * * * *",
  class: "CleanStaleTasksJob"
)
```

### Temporary Storage Validation for Blob Downloads

Jobs that download Active Storage blobs (hash lists, wordlists, rule files) should include the `TempStorageValidation` concern and call `ensure_temp_storage_available!(blob)` before processing. This prevents jobs from exhausting tmpfs space mid-download.

**Pattern:**

```ruby
class ProcessHashListJob < ApplicationJob
  include TempStorageValidation
  
  def perform(hash_list)
    ensure_temp_storage_available!(hash_list.file)
    hash_list.file.blob.open { |file| process(file) }
  end
end
```

**How it works:**

- The concern checks available space in `/tmp` against the blob's `byte_size` before calling `blob.open`
- Raises `InsufficientTempStorageError` if insufficient space available
- `ApplicationJob` automatically retries with polynomial backoff (5 attempts)
- After exhausting retries, job is discarded with structured log pointing to sizing documentation

**Jobs currently using this pattern:**

- `ProcessHashListJob` - validates before downloading hash lists
- `CountFileLinesJob` - validates before downloading wordlists, rule files, mask lists
- `CalculateMaskComplexityJob` - validates before downloading mask lists

**When creating new jobs** that process uploaded files:

1. Include `TempStorageValidation` concern
2. Call `ensure_temp_storage_available!(attachment)` before `blob.open`
3. The retry/discard behavior is handled automatically by `ApplicationJob`

This prevents jobs from repeatedly failing when tmpfs is undersized for the workload. Operators encountering discard logs should reference `docs/deployment/docker-storage-and-tmp.md` for tmpfs sizing guidance.

---

## Real-Time Features

### Turbo Streams

Models broadcast updates to connected clients:

```ruby
# app/models/task.rb
class Task < ApplicationRecord
  include SafeBroadcasting

  # Broadcasts refresh to all subscribers of this task
  broadcasts_refreshes unless Rails.env.test?
end
```

### Targeted Partial Updates with Turbo Streams

For more efficient real-time updates, broadcast specific partial updates instead of full pages. The `Agent::Broadcasting` concern (`app/models/concerns/agent/broadcasting.rb`) encapsulates all agent broadcast methods:

```ruby
# Agent broadcast methods are now in Agent::Broadcasting concern
module Agent::Broadcasting
  # Broadcast only when specific fields change
  after_update_commit :broadcast_index_state, if: -> { saved_change_to_state? }
  
  def broadcast_index_state
    broadcast_replace_later_to(
      self,
      target: dom_id(self, :index_state),  # Stable DOM ID
      partial: "agents/index_state",
      locals: { agent: self }
    )
  end

  # Replaces just the error count on index cards when a new AgentError is created.
  # Called from AgentError#after_create_commit to keep the broadcast contract on Agent,
  # matching the pattern of broadcast_index_state and broadcast_index_last_seen.
  def broadcast_index_errors
    broadcast_replace_later_to(
      self,
      target: dom_id(self, :index_errors),
      partial: "agents/index_errors",
      locals: { agent: self }
    )
  end
end
```

**Agent broadcast methods** (from `Agent::Broadcasting` concern) follow a consistent pattern for targeted partial updates:

- `broadcast_index_state` - Updates agent state badge (triggered by state changes)
- `broadcast_index_errors` - Updates error count (triggered when AgentError created)
- `broadcast_index_last_seen` - Updates last seen timestamp (triggered by last_seen_at changes)

**Critical Gotcha**: Broadcast partials run in background jobs with NO access to `current_user`, `session`, or request context. Partials must be completely self-contained and only use data passed in locals.

See examples in:

- `app/views/agents/_index_state.html.erb`
- `app/views/agents/_index_hash_rate.html.erb`
- `app/views/agents/_index_errors.html.erb`
- `app/views/agents/_index_last_seen.html.erb`

### Stimulus Controllers

```javascript
// app/javascript/controllers/auto_refresh_controller.js
import {
    Controller
} from "@hotwired/stimulus"

export default class extends Controller {
    static values = {
        interval: Number
    }

    connect() {
        this.startRefresh()
    }

    disconnect() {
        this.stopRefresh()
    }

    startRefresh() {
        this.refreshTimer = setInterval(() => {
            this.element.reload()
        }, this.intervalValue)
    }

    stopRefresh() {
        clearInterval(this.refreshTimer)
    }
}
```

---

## Database Conventions

### Migrations

**Always use Rails generators**:

```bash
# Good
bin/rails generate migration AddPriorityToAttacks priority:integer

# Bad - never create migration files manually
# Manual creation causes schema drift
```

### Transactions

Wrap related operations in transactions:

```ruby
def preempt_task(task)
  Task.transaction do
    task.lock!
    task.increment!(:preemption_count)
    task.update!(state: "pending", stale: true)
  end
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.error("[TaskPreemption] Failed: #{e.message}")
  nil
end
```

### Query Optimization

```ruby
# Good - eager loading
Attack.includes(:campaign, :word_list).where(state: :running)

# Good - select only needed columns
Task.select(:id, :state, :progress).where(agent: agent)

# Bad - N+1 query
Attack.all.each { |a| puts a.campaign.name }
```

### Partial Indexes for State-Based Queries

The codebase uses partial indexes to optimize common queries. Example from tasks table:

```ruby
add_index :tasks, :paused_at, where: "state = 'paused'"
```

This improves performance for orphaned task recovery queries that only target paused tasks. Partial indexes reduce index size and improve query speed by indexing only relevant rows.

### Fragment Cache Best Practices

**Never cache partials or components that contain authorization checks (`can?`) or CSRF tokens (`form_authenticity_token`).** Cached output is shared across all users, which can leak admin-only UI or serve invalid CSRF tokens.

```ruby
# Safe - no caching for auth-dependent components
<%= render AgentStatusCardComponent.new(agent: agent) %>

# Safe - cache: record for components with NO authorization/session content
<%= render StaticInfoComponent.new(record: record), cache: record %>

# Unsafe - caches can?/CSRF output, leaks across users
<%= render AgentStatusCardComponent.new(agent: agent), cache: agent %>
```

For collection partials, `cache: true` uses each record's `cache_key_with_version` — this is safe only when the partial contains no user-dependent content. When in doubt, omit caching; Turbo Stream broadcasts handle real-time freshness.

---

## Common Tasks

### Adding a New Model

```bash
# Generate model with migration
bin/rails generate model AgentMetric agent:references metric_type:string value:decimal

# Run migration
bin/rails db:migrate

# Generate factory
# spec/factories/agent_metrics.rb
```

### Adding a New API Endpoint

1. Add route in `config/routes/client_api.rb`
2. Add controller action in `app/controllers/api/v1/client/`
3. Add request spec in `spec/requests/api/v1/client/`
4. Regenerate docs: `RAILS_ENV=test rails rswag`

### Adding a Background Job

```bash
bin/rails generate job ProcessAgentMetrics
```

### Adding a ViewComponent

```bash
bin/rails generate component AgentStatus agent
```

---

## Common Gotchas

### Infrastructure Dependencies

**Temp Storage for Background Jobs**: Jobs that process uploaded files depend on properly sized tmpfs mounts at `/tmp`. When testing locally or in CI/CD, ensure tmpfs is configured (see `docker-compose.yml` for reference). Without adequate tmpfs, jobs will fail with `InsufficientTempStorageError`.

See `docs/deployment/docker-storage-and-tmp.md` for infrastructure setup guidance:

- Sizing tmpfs for concurrent blob downloads
- Monitoring tmpfs usage in production
- Recovery procedures for space exhaustion
- Alternative TMPDIR redirect approach

**Relevant GOTCHAS.md topics**: Review the "Temp Storage and File Uploads" section in `GOTCHAS.md` for additional context on Active Storage temp file behavior and upload constraints.

### Turbo Stream Broadcast Partials

- Broadcast partials (`broadcast_replace_to`, `broadcast_replace_later_to`) run in background jobs
- NO access to: `current_user`, `session`, `cookies`, `request`, or any controller context
- Must be completely self-contained and use only data passed via `locals`
- See GOTCHAS.md and Turbo Stream Broadcast Constraints documentation
- Use stable DOM IDs with `dom_id(record, :suffix)` for targeted updates

### Frontend Patterns

- Navbar dropdowns must use `<button type="button">`, not `<a href="#">` (scroll-to-top issue)
- Use Bootstrap z-index utilities (`z-1` through `z-3`) instead of inline styles
- Empty state icons: use `.empty-state-icon` class, not inline `style="font-size: 64px;"`
- Skeleton loaders: use `.skeleton-progress`, `.skeleton-avatar` classes
- After `bun run build:css`, run `touch tmp/restart.txt` to reload Propshaft asset cache
- `rails assets:clobber` deletes ALL build artifacts — run `just assets-build` to recover

### State Machine Cascades

- Agent shutdown can cascade to attack pause, which can cascade to task pause
- Task reclaim can trigger attack resume, which needs reload handling
- Use `update_columns` in state machine callbacks to avoid StaleObjectError
- See Agent Shutdown Cascade and StaleObjectError From Cascading Resume documentation

### Testing Turbo Streams

- Turbo Stream broadcasts can be tested with `assert_turbo_stream` helpers
- System tests may need to wait for broadcast updates with appropriate timeouts
- Background job processing (broadcasts use `_later_to`) must be enabled in test environment

---

## Getting Help

- **AGENTS.md**: Project conventions and patterns
- **GOTCHAS.md**: Common pitfalls and debugging tips
- **Architecture Docs**: `docs/architecture/`
- **API Reference**: `docs/api/`
- **Internal Documentation**:
  - Turbo Stream Broadcast Constraints
  - Agent Shutdown Cascade
  - Task State Machine Transitions
  - StaleObjectError From Cascading Resume
- **GitHub Issues**: For bugs and feature requests
- **PR Reviews**: Tag @unclesp1d3r for review
