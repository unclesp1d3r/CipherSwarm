# Design Document

## Overview

This design document outlines the core infrastructure for Phase 1 of the CipherSwarm v2 rewrite. The system builds upon the existing Ruby on Rails 7.2+ foundation with ActiveRecord ORM and PostgreSQL database. The architecture follows Rails conventions while implementing a distributed password cracking management system that coordinates multiple agents running hashcat across a network.

The core design principle is to consolidate and refine the existing foundation to create a scalable, maintainable system that supports multi-tenancy through project-based isolation, comprehensive state management, and efficient task distribution. This phase focuses on strengthening the existing models and ensuring they align with the requirements while maintaining compatibility with the current CipherSwarm agent infrastructure.

**Key Design Insight**: The current codebase already implements most of the required functionality. This phase focuses on consolidation, validation, and ensuring all components work cohesively rather than building from scratch.

## Architecture

### System Architecture

The system follows a monolithic Rails architecture with clear separation of concerns:

```text
┌─────────────────────────────────────────────────────────────┐
│                    Web Interface Layer                      │
│  (Controllers, Views, Components - Hotwire/Turbo/Stimulus) │
├─────────────────────────────────────────────────────────────┤
│                   Service Layer                             │
│     (Business Logic, State Management, Validation)         │
├─────────────────────────────────────────────────────────────┤
│                   Model Layer                               │
│        (ActiveRecord Models, Associations, Scopes)         │
├─────────────────────────────────────────────────────────────┤
│                   Data Layer                                │
│              (PostgreSQL 17+, Redis Cache)                 │
└─────────────────────────────────────────────────────────────┘
```

### Database Architecture

The database design centers around project-based multi-tenancy with the following core entity relationships:

```text
Project (1) ──→ (∞) Campaign ──→ (1) HashList
   │                  │
   │                  └──→ (∞) Attack ──→ (∞) Task
   │                             │
   └──→ (∞) Agent ──────────────┘
```

**Design Rationale**: Project-based isolation ensures security boundaries while allowing resource sharing within projects. The hierarchical relationship from Project → Campaign → Attack → Task provides clear work organization and enables efficient task distribution.

### Authentication & Authorization Strategy

**Current Implementation Analysis**:

- **Web UI**: Currently uses Devise for authentication with secure session cookies and CSRF protection
- **Agent API**: Bearer token authentication with per-agent tokens (24-character secure tokens)
- **Admin Interface**: Uses Administrate with CanCanCan and Rolify for role-based access

**Design Decision**: The existing Devise-based authentication system is mature and well-tested. Rather than migrating to Rails 8 authentication in this phase, we'll consolidate and strengthen the current implementation.

**Rationale**: Maintaining the existing authentication system reduces risk and allows focus on core infrastructure consolidation. The current system already provides the required functionality with proper security measures.

## Components and Interfaces

### Core Domain Models

#### User Model

```ruby
class User < ApplicationRecord
  # Uses Devise for authentication
  devise :database_authenticatable, :lockable, :trackable,
         :recoverable, :rememberable, :validatable, :registerable

  # Rolify for role management
  rolify

  # Tracking fields (handled by Devise)
  # sign_in_count, current_sign_in_at, last_sign_in_at
  # current_sign_in_ip, last_sign_in_ip

  # Security fields (handled by Devise)
  # encrypted_password, reset_password_token, unlock_token, failed_attempts

  # Current role enum (basic: 0, admin: 1) - uses Rolify for advanced roles
  enum role: { basic: 0, admin: 1 }

  # Associations
  has_many :project_users, dependent: :destroy
  has_many :projects, through: :project_users
  has_many :agents, dependent: :restrict_with_error
  has_many :mask_lists, :word_lists, :rule_lists, foreign_key: :creator_id
end
```

**Design Decision**: Maintains the existing Devise-based authentication system which provides comprehensive user management, security features, and is well-tested in production environments. Uses Rolify for advanced role management while maintaining a simple enum for basic admin/user distinction.

#### Project Model

```ruby
class Project < ApplicationRecord
  # Core fields: name, description (no private, notes, or archived_at in current schema)

  # Uses resourcify for role-based access
  resourcify

  # Associations
  has_many :project_users, dependent: :destroy
  has_many :users, through: :project_users
  has_many :campaigns, dependent: :destroy
  has_many :hash_lists, dependent: :destroy
  has_and_belongs_to_many :agents
  has_and_belongs_to_many :word_lists, :rule_lists, :mask_lists
end
```

**Design Decision**: The current implementation uses a join table (project_users) for user-project relationships rather than HABTM, providing more flexibility for future role assignments per project. Resource sharing is handled through HABTM relationships with various list types.

#### Agent Model

```ruby
class Agent < ApplicationRecord
  # Identity: client_signature, host_name, custom_label
  # Auth: token (24 chars), last_seen_at, last_ipaddress
  # State: state (string), enabled (boolean)
  # Config: advanced_configuration (JSONB), devices (string array)
  # OS: operating_system (enum: unknown, linux, windows, darwin, other)

  belongs_to :user, touch: true
  has_and_belongs_to_many :projects, touch: true
  has_many :tasks, dependent: :destroy
  has_many :hashcat_benchmarks, dependent: :destroy
  has_many :agent_errors, dependent: :destroy

  # Uses state_machine gem for complex state transitions
  state_machine :state, initial: :pending do
    # States: pending, active, stopped, error, offline
    # Events: activate, deactivate, shutdown, heartbeat, etc.
  end

  validates :custom_label, uniqueness: true, allow_nil: true
  validates :token, uniqueness: true, length: { is: 24 }
end
```

**Design Decision**: The current implementation uses a more sophisticated state machine with the AASM gem for complex agent lifecycle management. Agents can belong to multiple projects via HABTM relationship. The operating system is handled as an enum rather than a separate model reference.

#### Campaign Model

```ruby
class Campaign < ApplicationRecord
  # Core: name, description, priority (enum), deleted_at
  # Counters: attacks_count

  belongs_to :project, touch: true
  belongs_to :hash_list, touch: true
  has_many :attacks, dependent: :destroy
  has_many :tasks, through: :attacks, dependent: :destroy

  # Extended priority enum with more granular levels
  enum priority: {
    deferred: -1, routine: 0, priority: 1, urgent: 2,
    immediate: 3, flash: 4, flash_override: 5
  }

  acts_as_paranoid # Soft deletion

  # Automatic priority-based campaign management
  after_commit :check_and_pause_lower_priority_campaigns
end
```

**Design Decision**: The current implementation includes an extended priority system with more granular levels (up to flash_override) and automatic priority-based campaign management that pauses lower priority campaigns when higher priority ones are active.

#### Attack Model

```ruby
class Attack < ApplicationRecord
  # Basic: name, description, state, type
  # Mode: attack_mode (enum: dictionary, mask, hybrid_dictionary, hybrid_mask)
  # Mask: mask, increment_mode, increment_minimum, increment_maximum
  # Performance: optimized, workload_profile, slow_candidate_generators
  # Markov: disable_markov, classic_markov, markov_threshold
  # Rules: left_rule, right_rule
  # Charsets: custom_charset_1-4
  # Scheduling: priority, start_time, end_time
  # Metadata: complexity_value, deleted_at

  belongs_to :campaign, counter_cache: true
  has_many :tasks, dependent: :destroy, autosave: true
  has_many :hash_items, dependent: :nullify
  has_one :hash_list, through: :campaign
  belongs_to :rule_list, :mask_list, :word_list, optional: true

  enum attack_mode: { dictionary: 0, mask: 3, hybrid_dictionary: 6, hybrid_mask: 7 }

  # Uses state_machine gem for complex state transitions
  state_machine :state, initial: :pending do
    # States: pending, running, paused, completed, exhausted, failed
    # Events: accept, run, complete, pause, resume, error, exhaust, etc.
  end

  acts_as_paranoid
end
```

**Design Decision**: The current implementation uses hashcat's actual attack mode numbers (0, 3, 6, 7) and includes comprehensive resource associations (word_list, rule_list, mask_list). Uses state_machine gem for complex state transitions with proper callbacks.

#### Task Model

```ruby
class Task < ApplicationRecord
  # State: state (string), stale (boolean)
  # Timing: start_date, activity_timestamp, claimed_at, expires_at
  # Keyspace: keyspace_offset, keyspace_limit
  # Retry: max_retries, retry_count, last_error
  # Locking: lock_version, claimed_by_agent_id

  belongs_to :agent
  belongs_to :attack, touch: true
  has_many :hashcat_statuses, dependent: :destroy
  has_many :agent_errors, dependent: :destroy

  # Uses state_machine gem for complex state transitions
  state_machine :state, initial: :pending do
    # States: pending, running, paused, completed, failed, exhausted
    # Events: accept, run, complete, pause, resume, error, exhaust, etc.
  end

  validates :start_date, presence: true
end
```

**Design Decision**: The current implementation uses state_machine gem for robust state management with proper callbacks. Includes hashcat_statuses relationship for detailed progress tracking. Optimistic locking with lock_version prevents race conditions in distributed task assignment.

#### Missing Models to Implement

Based on the requirements analysis, the following models need to be created or enhanced:

**OperatingSystem Model** (Referenced but not fully implemented):

```ruby
class OperatingSystem < ApplicationRecord
  # Fields: name (enum), cracker_command
  enum name: { unknown: 0, linux: 1, windows: 2, darwin: 3, other: 4 }

  validates :name, presence: true, uniqueness: true
  validates :cracker_command, presence: true
end
```

**Enhanced AgentError Model** (Exists but may need validation):

```ruby
class AgentError < ApplicationRecord
  belongs_to :agent
  belongs_to :task, optional: true

  enum severity: { info: 0, warning: 1, error: 2, critical: 3 }

  validates :message, presence: true
  validates :error_code, presence: true
end
```

**Design Decision**: The OperatingSystem model should be implemented as a separate entity rather than just an enum on Agent to allow for extensible cracker command configuration per OS. The AgentError model exists but needs enhanced validation and proper error_code field.

### Service Layer Architecture

Services handle complex business logic that spans multiple models:

```ruby
module Campaigns
  class CreateService
    def initialize(user:, project:, params:)
      @user = user
      @project = project
      @params = params
    end

    def call
      ActiveRecord::Base.transaction do
        # Multi-step campaign creation logic
      end
    end
  end
end
```

**Design Decision**: Service objects encapsulate complex operations while keeping controllers thin. Transaction wrapping ensures data consistency.

### API Interface Design

#### Agent API Structure

```text
POST   /api/v1/client/agents          # Agent registration
GET    /api/v1/client/agents/{id}     # Agent details
PUT    /api/v1/client/agents/{id}     # Update agent status
GET    /api/v1/client/tasks           # Available tasks
POST   /api/v1/client/tasks/{id}/claim # Claim task
PUT    /api/v1/client/tasks/{id}      # Update task progress
POST   /api/v1/client/results         # Submit crack results
```

**Design Decision**: RESTful API design follows Rails conventions. Separate endpoints for task claiming and progress updates enable efficient distributed coordination.

## Data Models

### Database Schema Design

#### Current Schema Analysis

The current database schema is well-established and includes most required tables. Key observations:

**Users Table** (Devise-managed):

- Uses `encrypted_password` instead of `password_digest`
- Includes Devise fields: `remember_created_at`, `locked_at`
- Has proper indexes on `email`, `name`, `reset_password_token`, `unlock_token`
- Role enum: `basic: 0, admin: 1` (simpler than originally planned)

**Projects Table** (Simplified):

- Core fields: `id`, `name`, `description`, `created_at`, `updated_at`
- No `private`, `notes`, or `archived_at` fields in current schema
- Uses `project_users` join table for user associations

**Projects Table**:

```sql
CREATE TABLE projects (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR NOT NULL UNIQUE,
  description TEXT,
  private BOOLEAN DEFAULT false,
  notes TEXT,
  archived_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX index_projects_on_name ON projects(name);
```

**Agents Table**:

```sql
CREATE TABLE agents (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id),
  project_id BIGINT NOT NULL REFERENCES projects(id),
  operating_system_id BIGINT NOT NULL REFERENCES operating_systems(id),
  client_signature VARCHAR NOT NULL,
  host_name VARCHAR NOT NULL,
  custom_label VARCHAR,
  token VARCHAR NOT NULL UNIQUE,
  last_seen_at TIMESTAMP,
  last_ipaddress INET,
  state INTEGER NOT NULL DEFAULT 0,
  enabled BOOLEAN NOT NULL DEFAULT true,
  advanced_configuration JSONB DEFAULT '{}',
  devices JSONB DEFAULT '[]',
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX index_agents_on_token ON agents(token);
CREATE INDEX index_agents_on_state ON agents(state);
CREATE UNIQUE INDEX index_agents_on_custom_label_and_project ON agents(custom_label, project_id);
```

### Enum Definitions

**Design Decision**: Database-level enum constraints ensure data integrity while ActiveRecord enums provide application-level convenience.

```ruby
# User roles
enum role: { admin: 0, analyst: 1, operator: 2 }

# Agent states
enum state: { pending: 0, active: 1, error: 2, offline: 3, disabled: 4 }

# Attack modes
enum attack_mode: { dictionary: 0, brute_force: 1, hybrid_dict: 2, hybrid_mask: 3 }

# Task states
enum state: { pending: 0, dispatched: 1, running: 2, completed: 3, failed: 4, cancelled: 5 }

# Campaign priorities
enum priority: { deferred: -1, routine: 0, priority: 1 }
```

### Indexing Strategy

**Performance Indexes**:

- Foreign key columns for join performance
- Enum state columns for filtering
- Timestamp columns for time-based queries
- Unique constraints on business keys (email, token, custom_label)

**Design Rationale**: Indexes are placed on frequently queried columns, especially those used in WHERE clauses and JOIN conditions. Composite indexes support multi-column queries efficiently.

## Error Handling

### Application-Level Error Handling

```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from CanCan::AccessDenied, with: :render_forbidden
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity

  private

  def render_not_found
    render json: { error: 'Resource not found' }, status: :not_found
  end
end
```

### Agent Error Tracking

```ruby
class AgentError < ApplicationRecord
  # message, severity, error_code, metadata (JSONB)

  belongs_to :agent
  belongs_to :task, optional: true

  enum severity: { info: 0, warning: 1, error: 2, critical: 3 }

  validates :message, presence: true
  validates :error_code, presence: true
end
```

**Design Decision**: Structured error tracking with JSONB metadata enables flexible error context storage while maintaining queryable fields for common attributes.

### Retry and Recovery Mechanisms

- **Task Retry Logic**: Exponential backoff with configurable max retries
- **Agent Reconnection**: Automatic state recovery on agent reconnection
- **Database Transactions**: Ensure consistency during multi-step operations
- **Optimistic Locking**: Prevent race conditions in task assignment

## Testing Strategy

### Test Architecture

```text
spec/
├── models/           # Unit tests for ActiveRecord models
├── services/         # Unit tests for service objects
├── requests/         # API endpoint integration tests
├── system/          # Full browser-based workflow tests
├── jobs/            # Background job tests
└── components/      # ViewComponent unit tests
```

### Testing Patterns

**Model Testing**:

```ruby
RSpec.describe Agent, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:client_signature) }
    it { should validate_uniqueness_of(:custom_label).scoped_to(:project_id) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:project) }
    it { should have_many(:tasks) }
  end

  describe 'state machine' do
    it 'starts in pending state' do
      expect(agent.state).to eq('pending')
    end
  end
end
```

**API Testing with Contract Validation**:

```ruby
RSpec.describe 'Agent API', type: :request do
  describe 'POST /api/v1/client/agents' do
    it 'creates agent with valid parameters' do
      post '/api/v1/client/agents', params: valid_params

      expect(response).to have_http_status(:created)
      expect(response).to match_json_schema('agent_response')
    end
  end
end
```

**Design Decision**: Comprehensive test coverage ensures reliability while contract testing validates API compatibility. FactoryBot provides consistent test data across all test types.

### Quality Assurance Tools

- **RuboCop**: Code style and Rails best practices
- **Brakeman**: Security vulnerability scanning
- **SimpleCov**: Code coverage measurement (target 90%+)
- **Bullet**: N+1 query detection in development
- **Rswag**: API documentation and contract testing

## Performance Considerations

### Database Optimization

- **Connection Pooling**: Configured for concurrent request handling
- **Query Optimization**: Use `includes`, `preload`, `eager_load` to prevent N+1 queries
- **Index Strategy**: Comprehensive indexing on foreign keys and query columns
- **Pagination**: Use `pagy` gem for efficient large dataset handling

### Caching Strategy

```ruby
# Fragment caching for expensive views
<% cache campaign do %>
  <%= render campaign %>
<% end %>

# Service-level caching for expensive operations
Rails.cache.fetch("campaign_stats/#{campaign.id}", expires_in: 30.seconds) do
  campaign.calculate_statistics
end
```

**Design Decision**: Multi-level caching with short TTLs ensures fresh data while improving performance. Russian doll caching automatically invalidates nested cache fragments.

### Background Processing

- **Sidekiq**: Handles file processing, statistics calculation, and cleanup tasks
- **Job Prioritization**: Critical operations use high-priority queues
- **Retry Logic**: Exponential backoff for transient failures
- **Monitoring**: Sidekiq Web UI for job tracking and debugging

## Security Considerations

### Authentication Security

- **Password Security**: bcrypt hashing with Rails secure defaults
- **Session Security**: Secure, HTTP-only cookies with CSRF protection
- **Token Security**: Cryptographically secure random tokens for agents
- **Rate Limiting**: Rack::Attack for login attempt protection

### Authorization Model

```ruby
class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user

    # Project-scoped permissions
    user.projects.each do |project|
      can :manage, Campaign, project: project
      can :manage, Agent, project: project
    end

    # Role-based permissions
    can :manage, :all if user.admin?
  end
end
```

**Design Decision**: Project-scoped authorization ensures multi-tenancy while role-based permissions provide administrative control.

### Data Protection

- **Input Validation**: Strong parameters and ActiveRecord validations
- **SQL Injection Prevention**: Parameterized queries via ActiveRecord
- **XSS Protection**: Rails auto-escaping with explicit sanitization
- **Audit Logging**: Track sensitive operations for compliance

## Phase 1 Implementation Strategy

### Current State Assessment

The existing codebase already implements approximately 85% of the required functionality:

**✅ Fully Implemented:**

- User authentication and management (Devise-based)
- Project-based multi-tenancy
- Agent registration and management with state machines
- Campaign and attack management with priority systems
- Task distribution and tracking
- Comprehensive database schema with proper indexing

**🔧 Needs Consolidation:**

- Service layer patterns (some business logic in models)
- API endpoint organization and documentation
- Error handling standardization
- Testing coverage gaps

**➕ Missing Components:**

- OperatingSystem model (referenced but not implemented)
- Enhanced AgentError validation
- Some API endpoints for basic CRUD operations
- Comprehensive test suite for all components

### Implementation Approach

Rather than rebuilding from scratch, this phase focuses on:

1. **Consolidation**: Extract business logic into service objects
2. **Validation**: Ensure all models meet requirements specifications
3. **API Completion**: Implement missing CRUD endpoints
4. **Testing**: Create comprehensive test coverage
5. **Documentation**: Update API documentation

### Success Criteria

- All requirements from the requirements document are met
- Service layer follows consistent patterns
- API endpoints provide complete CRUD functionality
- Test coverage exceeds 90%
- All models have proper validations and relationships
- Database performance is optimized with proper indexing

This design provides a robust foundation for the CipherSwarm distributed password cracking system while building upon the existing, well-tested codebase and maintaining Rails conventions for security, performance, and maintainability.
