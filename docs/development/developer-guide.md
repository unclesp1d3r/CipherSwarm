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
08. [Background Jobs](#background-jobs)
09. [Real-Time Features](#real-time-features)
10. [Database Conventions](#database-conventions)
11. [Common Tasks](#common-tasks)

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

### Development Services

| Service    | URL                            | Description                            |
| ---------- | ------------------------------ | -------------------------------------- |
| Web App    | http://localhost:3000          | Main application                       |
| Sidekiq UI | http://localhost:3000/sidekiq  | Background job monitoring (admin only) |
| API Docs   | http://localhost:3000/api-docs | Swagger/OpenAPI documentation          |
| Admin      | http://localhost:3000/admin    | Administrate dashboard                 |

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

| Layer           | Technology                               |
| --------------- | ---------------------------------------- |
| Language        | Ruby 3.4.5                               |
| Framework       | Rails 8.0+                               |
| Database        | PostgreSQL 17+                           |
| Cache/Jobs      | Redis 7.2+ (Solid Cache, Sidekiq)        |
| Frontend        | Hotwire (Turbo + Stimulus), Tailwind CSS |
| Components      | ViewComponent                            |
| Authentication  | Rails 8 Auth + Devise                    |
| Authorization   | CanCanCan + Rolify                       |
| Background Jobs | Sidekiq + Sidekiq-Cron                   |
| API Docs        | RSwag (OpenAPI)                          |

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

---

## Code Organization

### Directory Structure

```
app/
├── channels/        # Action Cable channels
├── components/      # ViewComponent components
├── controllers/
│   ├── api/v1/      # Agent API controllers
│   │   └── client/  # Client-specific endpoints
│   └── concerns/    # Controller concerns
├── dashboards/      # Administrate dashboards
├── helpers/         # View helpers
├── inputs/          # SimpleForm inputs
├── jobs/            # Sidekiq background jobs
├── mailers/         # Email templates
├── models/
│   └── concerns/    # Model concerns
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

All API endpoints require bearer token authentication:

```ruby
# app/controllers/api/v1/base_controller.rb
class Api::V1::BaseController < ApplicationController
  before_action :authenticate_agent

  private

  def authenticate_agent
    token = request.headers["Authorization"]&.split(" ")&.last
    @agent = Agent.find_by(token: token)

    render_unauthorized unless @agent
  end

  def render_unauthorized
    render json: { error: "Invalid token" }, status: :unauthorized
  end
end
```

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

## Background Jobs

### Job Structure

```ruby
# app/jobs/process_hash_list_job.rb
# frozen_string_literal: true

class ProcessHashListJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Handle deserialization errors (record deleted before job runs)
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.warn(
      "[JobDiscarded] ProcessHashListJob: #{error.message}"
    )
  end

  def perform(hash_list)
    HashListProcessor.new(hash_list).process
  end
end
```

### Queue Priorities

| Queue    | Use Case                    |
| -------- | --------------------------- |
| default  | General background work     |
| critical | Time-sensitive operations   |
| low      | Non-urgent batch processing |

### Scheduled Jobs

Configure in `config/initializers/sidekiq.rb`:

```ruby
Sidekiq::Cron::Job.create(
  name: "Clean stale tasks - every hour",
  cron: "0 * * * *",
  class: "CleanStaleTasksJob"
)
```

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

## Getting Help

- **AGENTS.md**: Project conventions and patterns
- **Architecture Docs**: `docs/architecture/`
- **API Reference**: `docs/api/`
- **GitHub Issues**: For bugs and feature requests
- **PR Reviews**: Tag @unclesp1d3r for review
