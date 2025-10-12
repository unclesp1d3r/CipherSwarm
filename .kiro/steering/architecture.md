---
inclusion: always
---

# CipherSwarm Architecture Guide

## Project Overview

CipherSwarm is a distributed password cracking management system built with Ruby on Rails 8.0+. It coordinates multiple agents running hashcat to efficiently distribute password cracking tasks across a network of machines.

## Critical Requirements

### API Compatibility

**Agent API v1 (`/api/v1/client/*`)**

- MUST maintain full compatibility with v1 contract specification
- Legacy compatibility with existing agents
- Breaking changes prohibited
- Contract is authoritative source for all behavior

**Agent API v2 (`/api/v2/client/*`)**

- NOT YET IMPLEMENTED
- Will allow modern Rails API designs and breaking changes
- Cannot interfere with v1 API

**Testing Requirements**

- Validate API responses against OpenAPI specification with Rswag
- Contract testing for specification compliance
- RSpec request specs verify exact schema matches
- System tests with Capybara for full user workflows

## Architecture

### Backend Stack

- **Ruby on Rails 8.0+**: Monolithic web framework with REST API
- **Ruby 3.4.5**: Runtime environment managed with rbenv
- **PostgreSQL 17+**: Primary database with ActiveRecord ORM
- **Redis 7.2+**: Caching and background job queues
- **ActiveStorage**: S3-compatible object storage for attack resources
- **Rails Logger**: Structured logging with tagged logging support

### Core Domain Models

- **Project**: Top-level security boundary isolating all resources
- **Campaign**: Coordinated cracking operation targeting a single hash list
- **Attack**: Specific hashcat configuration (mode, rules, masks, etc.)
- **Task**: Discrete work unit assigned to an agent
- **HashList**: Collection of hashes targeted by campaigns
- **HashItem**: Individual hash with metadata (salt, username, etc. in JSONB)
- **Agent**: Registered client executing tasks with capability benchmarks
- **CrackResult**: Successfully cracked hash with discovery metadata
- **Session**: Task execution lifecycle tracking
- **User**: Authenticated entity with project-scoped permissions

### Key Relationships

- Project → Campaigns (1:many)
- Campaign → HashList (many:1)
- Campaign → Attacks (1:many)
- Attack → Tasks (1:many)
- HashList ↔ HashItems (many:many)
- Agent executes Tasks, reports CrackResults

### API Structure

**Agent API** (`/api/v1/client/*`)

- Agent registration, heartbeat, task management
- Controller files: `app/controllers/api/v1/client/{resource}_controller.rb`
- Routes defined in `config/routes/api.rb`

**Web UI Routes**

- Campaign management, monitoring, visualization
- Controller files: `app/controllers/{resource}s_controller.rb`
- Server-rendered views with Turbo Streams for real-time updates

**Admin Interface** (`/admin/*`)

- Administrative controls and system configuration
- Controller files: `app/controllers/admin/{resource}_controller.rb`
- Role-based access via CanCanCan

**Shared Infrastructure**

- Cross-cutting concerns (users, sessions, authentication)
- Files: `app/controllers/application_controller.rb`, concerns in `app/controllers/concerns/`

### Frontend Stack

**Hotwire (Turbo 8 + Stimulus 3.2+)**

- Server-rendered HTML with progressive enhancement
- Turbo Drive for fast page navigation
- Turbo Frames for partial page updates
- Turbo Streams for real-time updates via ActionCable
- Stimulus controllers for interactive behaviors

**UI Libraries**

- Tailwind CSS v4: Utility-first CSS framework with custom Catppuccin Macchiato theme
- ViewComponent 4.0+: Server-side component library for reusable UI elements
- Rails form helpers: Server-side form generation with validation
- Built-in dark mode and WCAG 2.1 AA accessibility compliance

**Key Features**

- Agent management dashboard
- Attack configuration interface
- Real-time task monitoring
- Results visualization

## Core Concepts

### State Machines

Use AASM gem for entity lifecycle management:

- **Agent States**: `registered` → `active` → `disconnected` → `reconnecting` → `retired`

- **Campaign States**: `draft` → `scheduled` → `running` → `paused` → `completed`

- **Attack States**: `pending` → `running` → `paused` → `completed` → `exhausted`

- **Task States**: `pending` → `dispatched` → `running` → `complete` → `validated`

- Use AASM gem for state machine definitions in models

- Validate transitions via AASM guards and callbacks

- Never allow direct state writes, use AASM events

- Log all state transitions via Audited gem

### Attack System

- **Modes**: Dictionary, Mask, Hybrid Dictionary, Hybrid Mask
- **Resources**: Word lists, rule lists, mask patterns, custom charsets
- **Storage**: ActiveStorage with S3-compatible backend (MinIO in reference implementation), direct uploads
- **Organization**: Project-scoped resources with sharing capabilities

### Task Distribution

- Keyspace slicing for parallel execution
- Real-time progress tracking
- Result collection and validation
- Error handling and retry logic

## Development Guidelines

### Service Layer Architecture

- All business logic in `app/services/` or model concerns in `app/models/concerns/`
- Controllers are thin wrappers that delegate to models and services
- Service objects for complex, multi-model operations
- Follow Rails conventions: fat models, skinny controllers
- Use ActiveRecord callbacks for lifecycle hooks
- Return ActiveRecord objects or collections

### Code Organization

- Models: `app/models/{resource}.rb` (ActiveRecord models)
- Controllers: `app/controllers/{resource}s_controller.rb`
- Services: `app/services/{domain}/{action}_service.rb`
- Views: `app/views/{resource}/` (ERB templates)
- Components: `app/components/{resource}_component.rb` (ViewComponent)
- Jobs: `app/jobs/{action}_job.rb` (Sidekiq/ActiveJob)
- Use Rails migrations for database schema changes
- Type annotations with RBS optional

### Logging

- Use Rails.logger throughout (configured with tagged logging)
- Structured logs with tagged context (request ID, user ID)
- Log levels: debug, info, warn, error, fatal
- Emit to stdout for containerized environments
- Use ActiveSupport::Notifications for instrumentation

### Caching

- Use Solid Cache backed by Redis for production
- Fragment caching for view partials
- Russian doll caching for nested resources
- Short TTLs (≤60s) unless justified
- Logical key prefixes: `campaign_stats/`, `agent_health/`
- Use cache sweepers or touch associations for invalidation

### Authentication

- **Web UI**: Rails 8 authentication with session cookies, CSRF protection
- **Agent API**: Bearer tokens with custom authentication strategy
- **Admin Panel**: Role-based access via CanCanCan with Rolify roles

All sessions use secure cookies, automatic expiration, and audit logging via Audited gem.

### Error Handling

- Raise domain-specific exceptions in models/services
- Rescue and render appropriate responses in controllers
- Agent API v1: Match legacy error schema exactly
- Web UI: Render error pages or flash messages
- Use Rails rescue_from for consistent error handling
- Never expose internal errors or stack traces in production

### Testing Strategy

- Model specs for validations, associations, and business logic
- Request specs for API endpoints with Rswag contract testing
- System specs with Capybara for full user workflows
- Job specs for background processing
- Component specs for ViewComponent units
- Use FactoryBot for test data, VCR for HTTP interactions

## Docker Configuration

### Required Services

- **app**: Rails 8 (Ruby 3.4.5, Thruster proxy, health checks)
- **db**: PostgreSQL 17+ (persistent volumes, automated backups)
- **redis**: Caching (Solid Cache) and job queues (Sidekiq)
- **sidekiq**: Background job processing
- **nginx**: Optional reverse proxy (SSL termination, load balancing)

### Container Standards

- Non-root users in all containers
- Multi-stage builds for app image
- Health checks for all services via SidekiqAlive and database monitoring
- Environment variables via Rails credentials
- Named volumes for persistent data
- Single command deployment: `kamal deploy` or `docker compose up -d`

### Deployment Strategy

- **Development**: Docker Compose with hot reloading
- **Production**: Kamal 2 for zero-downtime deployments
- **Asset Compilation**: Propshaft for production asset pipeline
- **Process Management**: Thruster for HTTP/2 and WebSocket support
- **Health Monitoring**: Comprehensive checks for Rails, Sidekiq, and database

## Security Best Practices

### Rails Security

- **Input Validation**: Use strong parameters and ActiveRecord validations
- **SQL Injection Prevention**: Use parameterized queries via ActiveRecord (never raw SQL concatenation)
- **XSS Protection**: Rails auto-escapes ERB output, use `sanitize` for user HTML
- **CSRF Protection**: Enabled by default with `protect_from_forgery`
- **Mass Assignment Protection**: Use strong parameters in controllers
- **Secret Management**: Use Rails encrypted credentials, never commit secrets

### API Security

- **Authentication**: Session-based for web UI, token-based for agents
- **Authorization**: CanCanCan for ability checks, Rolify for role assignment
- **Rate Limiting**: Implement Rack::Attack for API endpoint protection
- **HTTPS Only**: Enforce SSL in production via `force_ssl`
- **Audit Logging**: Use Audited gem for sensitive operation tracking

### Data Security

- **Encryption**: Use ActiveRecord encryption for sensitive fields
- **Access Control**: Project-level resource isolation via multi-tenancy
- **Session Security**: Secure, HTTP-only cookies with short expiration
- **Database Security**: Connection pooling, read-only replicas for reporting

## Performance Optimization

### Database Optimization

- **Query Optimization**: Use `includes`, `preload`, `eager_load` to prevent N+1 queries
- **Indexing**: Add database indexes for frequently queried columns
- **Connection Pooling**: Configure appropriate pool size for production workload
- **Query Caching**: Use Solid Cache for expensive query results
- **Bullet Gem**: Use in development to detect N+1 queries and unused eager loading

### Caching Strategy

- **Fragment Caching**: Cache expensive view partials
- **Russian Doll Caching**: Nest caches with touch associations for auto-invalidation
- **Action Caching**: Cache entire controller actions where appropriate
- **HTTP Caching**: Set ETags and Last-Modified headers for conditional requests
- **Cache Keys**: Use versioned cache keys that include model timestamps

### Background Processing

- **Sidekiq Jobs**: Move slow operations to background jobs
- **Job Prioritization**: Use queue priorities for critical vs. batch operations
- **Job Retries**: Configure retry logic with exponential backoff
- **Batch Processing**: Use Sidekiq batch operations for bulk work
- **Job Monitoring**: Track job performance and failure rates

### Asset Optimization

- **Propshaft**: Rails 8 default for fast asset serving
- **Compression**: Enable gzip/brotli compression via Thruster
- **CDN**: Use CDN for static assets in production
- **Image Optimization**: Optimize images before upload, use appropriate formats
- **CSS/JS Minification**: Automatic via Propshaft in production

## Development Workflow

### Local Development

- **Setup**: Use `bin/setup` for initial configuration
- **Server**: Run `bin/dev` to start Rails with Procfile configuration
- **Database**: Use `rails db:migrate` for schema changes
- **Console**: Use `rails console` for interactive debugging
- **Generators**: Use Rails generators for models, controllers, views, etc.

### Code Quality Tools

- **RuboCop**: Enforce Ruby style guide with Rails Omakase config
- **Brakeman**: Security vulnerability scanner
- **Bullet**: N+1 query detector in development
- **SimpleCov**: Code coverage measurement
- **Reek**: Code smell detector

### Testing Workflow

- **Run Tests**: `rspec` or `rspec spec/path/to/test_spec.rb`
- **System Tests**: `rspec spec/system` for browser-based tests
- **Test Database**: Automatically managed by RSpec
- **Coverage Reports**: Generated by SimpleCov after test runs
- **CI Integration**: GitHub Actions for automated testing

### Database Management

- **Migrations**: Create with `rails generate migration`
- **Schema**: Keep `db/schema.rb` in version control
- **Seeds**: Use `db/seeds.rb` for development data
- **Reset**: `rails db:reset` to drop, create, migrate, and seed
- **Rollback**: `rails db:rollback` to undo migrations

## Deployment Strategy

### Kamal 2 Deployment

- **Configuration**: `config/deploy.yml` defines deployment settings
- **Deploy**: `kamal deploy` for zero-downtime deployments
- **Rollback**: `kamal rollback` to revert to previous version
- **Logs**: `kamal app logs` for application logs
- **Shell Access**: `kamal app exec` for container shell access

### Environment Configuration

- **Credentials**: Use Rails encrypted credentials per environment
- **Environment Variables**: Set via `config/credentials.yml.enc`
- **Database**: PostgreSQL 17+ with connection pooling
- **Redis**: For Solid Cache and Sidekiq queues
- **Assets**: Precompiled via Propshaft before deployment

### Monitoring and Maintenance

- **Health Checks**: Built-in health check endpoints
- **Application Monitoring**: Track request rates, response times, errors
- **Background Job Monitoring**: Sidekiq Web UI for job tracking
- **Database Monitoring**: Track query performance and connection usage
- **Log Aggregation**: Centralized logging for production environments

---

## Rails Service Layer Patterns

### When to Use Service Objects

Use service objects for:

- Complex business logic spanning multiple models
- Operations requiring multiple database transactions
- External API integrations
- Background job coordination
- Domain logic that doesn't fit naturally in a single model

Keep in models:

- Simple CRUD operations
- Single-model validations and callbacks
- Scopes and query methods
- Associations and relationships

### Service Organization

**File Structure**:

- Services in `app/services/{domain}/`
- One service class per operation
- Example: `app/services/campaigns/create_service.rb`

**Naming Pattern**:

```ruby
module Campaigns
  class CreateService
    def initialize(user:, project:, params:)
      @user = user
      @project = project
      @params = params
    end

    def call
      # Service logic here
    end
  end
end
```

**Controller Usage**:

```ruby
def create
  result = Campaigns::CreateService.new(
    user: current_user,
    project: @project,
    params: campaign_params
  ).call

  if result.success?
    redirect_to result.campaign
  else
    render :new, status: :unprocessable_entity
  end
end
```

### Model Concerns

Use concerns to extract reusable model behavior:

**File Structure**: `app/models/concerns/{concern_name}.rb`

```ruby
# app/models/concerns/state_machine.rb
module StateMachine
  extend ActiveSupport::Concern

  included do
    include AASM

    aasm column: :state do
      state :draft, initial: true
      state :running, :paused, :completed

      event :start do
        transitions from: :draft, to: :running
      end

      event :pause do
        transitions from: :running, to: :paused
      end

      event :resume do
        transitions from: :paused, to: :running
      end

      event :complete do
        transitions from: [:running, :paused], to: :completed
      end
    end
  end
end
```

**Model Usage**:

```ruby
class Campaign < ApplicationRecord
  include StateMachine
  # Additional model logic
end
```

### Background Jobs

Use Sidekiq for async operations:

**File Structure**: `app/jobs/{action}_job.rb`

```ruby
class ProcessHashListJob < ApplicationJob
  queue_as :default

  def perform(hash_list_id)
    hash_list = HashList.find(hash_list_id)
    # Processing logic
  end
end
```

**Enqueue from Controller**:

```ruby
def create
  @hash_list = HashList.create(hash_list_params)
  ProcessHashListJob.perform_later(@hash_list.id)
  redirect_to @hash_list
end
```

## Controller Best Practices

### Keep Controllers Thin

```ruby
# Bad: Business logic in controller
def create
  @campaign = Campaign.new(campaign_params)
  @campaign.project = current_project
  @campaign.creator = current_user

  if @campaign.save
    @campaign.attacks.each do |attack|
      attack.tasks.create!(/* params */)
    end
    CampaignMailer.created(@campaign).deliver_later
    redirect_to @campaign
  else
    render :new
  end
end

# Good: Delegate to service
def create
  result = Campaigns::CreateService.new(
    user: current_user,
    project: current_project,
    params: campaign_params
  ).call

  if result.success?
    redirect_to result.campaign
  else
    @campaign = result.campaign
    render :new
  end
end
```

### Use Strong Parameters

```ruby
def campaign_params
  params.require(:campaign).permit(
    :name,
    :description,
    :hash_list_id,
    attacks_attributes: [:id, :attack_mode, :wordlist_id, :_destroy]
  )
end
```

### Handle Authorization

```ruby
before_action :authenticate_user!
before_action :set_campaign, only: [:show, :edit, :update, :destroy]
load_and_authorize_resource except: [:index, :new, :create]

private

def set_campaign
  @campaign = Campaign.find(params[:id])
  authorize! :read, @campaign
end
```

## Rails Conventions Summary

### Follow Rails Patterns

- **Convention Over Configuration**: Use Rails defaults unless there's a strong reason not to
- **RESTful Routes**: Stick to standard resource routing patterns
- **Fat Models, Skinny Controllers**: Business logic in models/services, not controllers
- **DRY Principle**: Extract common code into concerns, helpers, or services
- **SOLID Principles**: Single responsibility, open/closed, Liskov substitution, interface segregation, dependency inversion

### Code Organization

- Models handle data and simple business logic
- Controllers coordinate requests and responses
- Services handle complex multi-model operations
- Jobs handle background processing
- Concerns extract reusable behavior
- Helpers provide view-specific utilities
- Components encapsulate reusable UI elements

### Testing Philosophy

- Write tests first when possible (TDD)
- Test behavior, not implementation
- Use factories for test data
- Mock external dependencies
- Aim for high coverage but focus on critical paths
- Run tests frequently during development
