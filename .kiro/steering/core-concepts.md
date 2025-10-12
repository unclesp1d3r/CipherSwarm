---
inclusion: always
---

# CipherSwarm Core Concepts

## Database Models

The backend defines a set of structured models to represent key operational and engagement data. These include:

- `Project`: The top-level organizational and security boundary. Projects isolate agents, campaigns, hash lists, and users from one another. Access control is enforced at the project level, and no data is shared across projects without explicit export.
- `Campaign`: A coordinated set of cracking attempts targeting a single hash list. Each campaign groups multiple attacks and serves as the operational unit for tracking progress and outcomes.
- `Attack`: A specific cracking configuration (mode, rules, masks, charsets, etc.) used within a campaign. Multiple attacks may be chained or run in sequence under a campaign to exhaust various approaches.
- `Task`: A discrete unit of work derived from an attack, assigned to a single agent. A task defines the keyspace slice, associated resources, and reporting path.
- `HashList`: A set of hashes targeted by a campaign. Each campaign is linked to one hash list, but a hash list may be reused across multiple campaigns.
- `HashItem`: An individual hash within a hash list. May include format-specific metadata such as salt or encoding. They may also contain user-defined metadata such as username and source, which should be stored as a JSONB.
- `Agent`: A registered client capable of executing tasks. Agents report capability benchmarks, maintain a stateful heartbeat, and are tracked for version, platform, and operational health.
- `CrackResult`: A record of a successfully cracked hash. Includes metadata about the agent, attack, and time of discovery.
- `AgentError`: A fault or exception reported by an agent, optionally tied to a specific attack.
- `Session`: Tracks the lifecycle of an active task execution, including live progress, last update time, and final disposition.
- `Audit`: Historical log of user and system actions. Tracks changes to campaigns, attacks, task states, and user activity for accountability.
- `User`: An authenticated entity authorized to access projects and perform actions. Permissions are scoped by role (`admin`, `user`, `power user`) and project membership.

### **Relationships**

- A Project has many Campaigns, but each Campaign belongs to exactly one Project.
- A User may belong to many Projects, and a Project may have many Users. (Many-to-many)
- A Campaign has many Attacks, but each Attack belongs to exactly one Campaign.
- An Attack has one or more Tasks, but each Task belongs to exactly one Attack.
- A Campaign is associated with a single HashList, but a HashList can be associated with many Campaigns. (Many-to-one from Campaign to HashList)
- A HashList has many HashItems, and a HashItem can belong to many HashLists. (Many-to-many)
- A CrackResult is associated with exactly one Attack, one HashItem, and one Agent.
- An AgentError always belongs to one Agent, and may optionally be associated with a single Attack.

Join tables such as `AgentsProjects` are used to enforce multi-tenancy boundaries or cross-link entities.

### **API Interfaces**

#### **Agent API** (`/api/v1/client/*`)

- Used by distributed CipherSwarm agents
- Handles agent registration and heartbeat
- Task distribution and result collection
- Benchmark submission
- Error reporting
- Located under `app/controllers/api/v1` directory; wasn't previously located there, but should be moved.

#### **Control API** (`/api/v1/control/*`)

- Future Python TUI/CLI client interface
- Command-line based management
- Real-time monitoring
- Batch operations
- Scriptable interface
- Located under `app/controllers/api/v1/control` directory; wasn't previously located there, but should be moved.

### Frontend Components

#### **Hotwire-Based UI**

- Built with Hotwire/Stimulus (SPA pre-build)
- Follow Hotwire/Stimulus conventions for routing and state management
- Responsive, accessible, and modern UX
- When writing Hotwire components, aspire to use idiomatic Hotwire (<https://hotwire.dev/llms-small.txt>)

#### **Component Library**

- Use a well-maintained component library for UI components
- Enterprise-ready dashboard components
- Consistent design language across the application
- Built-in dark mode support and accessibility compliance
- Key components used:
  - Forms for attack setup
  - Tables for task management
  - Progress indicators for cracking status
  - Cards for agent and task display
  - Navigation components for dashboard layout
  - Stats components for metrics display
- Key components used:
  - Data tables for task management
  - Progress indicators for cracking status
  - Alert components for notifications
  - Modal dialogs for configuration
  - Form components for attack setup
  - Cards for agent and task display
  - Navigation components for dashboard layout
  - Stats components for metrics display

#### **Key Features**

- Agent management dashboard
- Attack configuration interface
- Real-time task monitoring
- Results visualization

#### **Python control CLI** (Planned via Control API)

- Command-line interface
- Real-time monitoring
- Batch operations
- Scriptable workflows

## Core Concepts

### Agent Management

#### **Agent States**

- `pending`: Initial registration state
- `active`: Ready for tasks
- `stopped`: Manually paused
- `error`: Encountered issues

#### **Agent Configuration**

- Update intervals
- Device selection (CPU/GPU)
- Hashcat configuration
- Benchmark management

### Attack System

#### **Attack Modes**

- Dictionary attacks
- Mask attacks
- Hybrid dictionary attacks
- Hybrid mask attacks

#### **Attack Resources**

- Word lists
- Rule lists
- Mask patterns
- Custom charsets

#### **Resource Storage**

- All static attack resources stored in MinIO S3-compatible storage
- Resources include:
  - Word lists for dictionary attacks
  - Rule lists for rule-based attacks
  - Mask pattern lists for mask attacks
  - Custom charset files
- Each resource file has:
  - Unique identifier
  - MD5 checksum for verification
  - Metadata including size, upload date, and description
  - S3 presigned URLs for secure agent downloads
- Web UI requirements:
  - Direct file uploads to MinIO buckets
  - Progress tracking for large files
  - Checksum verification
  - Resource management interface
  - File preview capabilities
  - Resource tagging and categorization
- MinIO Configuration:
  - Bucket Structure:
    - `wordlists/`: Dictionary attack word lists
    - `rules/`: Hashcat rule files
    - `masks/`: Mask pattern files
    - `charsets/`: Custom charset definitions
    - `temp/`: Temporary storage for uploads
  - File Organization:
    - Files stored with UUID-based names
    - Original filenames stored in metadata
    - Version control through metadata tags
  - Backup Configuration:
    - Automatic daily snapshots
    - Version retention policies
    - Cross-region replication (optional)
- Security Implementation:
  - Access Control:
    - Bucket policies for strict access control
    - Use ActiveStorage for file uploads and downloads
    - Role-based access for web UI users
    - IP-based restrictions for agent access
  - Data Protection:
    - Server-side encryption at rest
    - TLS for all transfers
    - Automatic virus scanning for uploads
    - File type verification
  - Monitoring:
    - Access logging
    - Usage metrics
    - Error tracking
    - Quota management

### Task Distribution

#### **Task Lifecycle**

- Creation and assignment
- Progress monitoring
- Result collection
- Completion/abandonment

#### **Task Features**

- Keyspace distribution
- Progress tracking
- Real-time status updates
- Error handling

## Project Structure

### Docker Configuration

#### **Service Containers**

- Rails Application:
  - Bundler package manager
  - Development and production configurations
  - Health checks
  - Graceful shutdown handling
- PostgreSQL Database:
  - Version 17 or later
  - Persistent volume mounts
  - Automated backups
  - Replication support (optional)
- Redis Cache:
  - Version 7.2+ required
  - Solid Cache backend for production
  - Sidekiq task queue backend
  - Optional in development (uses memory store)
- MinIO Object Storage:
  - Latest stable version
  - Configured buckets for attack resources
  - TLS/SSL support
  - Access key management
- Thruster Reverse Proxy:
  - Latest stable version
  - SSL termination
  - Rate limiting
  - Static file serving
- Monitoring Stack (Optional):
  - Prometheus
  - Grafana
  - Node Exporter
  - Cadvisor

#### **Development Setup**

1. **Container Security**

```
- Non-root users in all containers
- Read-only root filesystem where possible
- Limited container capabilities
- Resource limits and quotas
- Regular security scanning
- Secrets management via environment files
```

2. **Deployment Requirements**

   - Single command deployment: `docker compose up -d`
   - Automated database migrations
   - Health check monitoring
   - Backup and restore procedures
   - Log aggregation
   - Monitoring and alerting
   - Zero-downtime updates
   - Rollback capabilities

3. **Development Workflow**

   - Hot reload for development
   - Shared volume mounts for code changes
   - Development-specific overrides
   - Test environment configuration
   - Debug capabilities
   - Local resource access

4. **CI/CD Integration**

   - Automated builds
   - Container testing
   - Security scanning
   - Registry pushes
   - Deployment automation
   - Environment promotion

5. **Backup Strategy**

   - Database dumps
   - MinIO bucket backups
   - Configuration backups
   - Automated scheduling
   - Retention policies
   - Restore testing

6. **Monitoring Setup**

   - Container metrics
   - Application me - Resource usage
   - Alert configuration
   - Log management
   - Performance tracking

7. **Scaling Configuration**

   - Service replication
   - Load balancing
   - Database clustering
   - Cache distribution
   - Storage expansion
   - Backup scaling

## Development Guidelines

### Logging

All application logging MUST use `Rails.logger` with tagged logging for context.

- Logs should be structured, timestamped, and consistently leveled (`debug`, `info`, `warn`, `error`, `fatal`)
- Use `Rails.logger.tagged()` for attaching context (e.g., task ID, agent ID, request ID)
- Ensure logs emit to stdout by default for compatibility with containerized environments
- Use `ActiveSupport::Notifications` for performance instrumentation

### Code Organization

1. **API Versioning**

   - Agent API versioning controlled by `swagger/v1/swagger.json` specification (generated by Rswag)
   - Agent, Web UI, and Control APIs versioned independently
   - Version-specific controllers in `app/controllers/api/v1/`
   - Backward compatibility maintenance

2. **Database Practices**

   - Rails migrations for schema changes (`rails generate migration`)
   - ActiveRecord for database operations
   - Strong parameters and model validations
   - Database indexes for performance

3. **Security Considerations**

   - Rails 8 authentication with session cookies
   - Bearer token authentication for agents
   - Agent verification
   - Secure resource downloads via ActiveStorage
   - Air-gapped network support

### Authentication Strategies

1. **Web UI Authentication**

   - Rails 8 authentication with password-based login
   - Session-based with secure HTTP-only cookies
   - CSRF protection enabled by default (`protect_from_forgery`)
   - Rate limiting on login attempts via Rack::Attack
   - Password requirements:
     - Minimum length and complexity
     - Password hashing with bcrypt (Rails default)
     - Regular password rotation policies
   - Remember-me functionality with secure tokens

2. **Agent API Authentication**

   - Bearer token authentication
   - Tokens automatically generated on agent registration
   - One token per agent, bound to agent ID
   - Token rotation on security events
   - Automatic token invalidation on agent removal
   - Custom authentication strategy in `app/controllers/concerns/`

3. **Control API Authentication** (Planned)

   - API key-based authentication using bearer tokens
   - Keys generated through web interface
   - Associated with specific user accounts
   - Configurable permissions and scopes via CanCanCan
   - Token format: `cst_<user_id>_<random_string>`
   - Multiple active keys per user supported
   - Key management features:
     - Key creation with expiration
     - Scope configuration
     - Usage monitoring via Audited gem
     - Emergency revocation

4. **Common Security Features**

   - All tokens transmitted over HTTPS only (enforced via `force_ssl`)
   - Automatic session/token expiration
   - Token revocation capabilities
   - Audit logging via Audited gem
   - Failed attempt monitoring
   - IP-based rate limiting via Rack::Attack
   - Security event notifications

### 🔁 Caching

CipherSwarm uses Solid Cache backed by Redis for production caching and Rails' built-in caching mechanisms.

- All caching uses Rails.cache API (`Rails.cache.fetch`, `Rails.cache.read`, `Rails.cache.write`)
- Memory store caching in development
- Solid Cache with Redis backend in production
- Fragment caching for view partials
- Russian doll caching for nested resources

#### 🔒 Usage Constraints

- TTLs should be short (≤ 60s) unless a strong reason exists
- All cache keys should be prefixed logically, e.g. `campaign_stats/`, `agent_health/`
- Avoid caching large serialized objects unless explicitly required
- Use `touch: true` associations for automatic cache invalidation
- Use cache sweepers or explicit `expire_fragment` for manual invalidation
- Prefer fragment caching in views and low-level caching in models

#### 🧠 Examples

```ruby
# Low-level caching in models/services
Rails.cache.fetch("campaign_stats/#{campaign.id}", expires_in: 30.seconds) do
  campaign.calculate_statistics
end

# Fragment caching in views
<% cache campaign do %>
  <%= render campaign %>
<% end %>

# Russian doll caching
<% cache campaign do %>
  <h1><%= campaign.name %></h1>
  <% cache campaign.attacks do %>
    <%= render campaign.attacks %>
  <% end %>
<% end %>
```

### Best Practices

1. **API Design**

   - RESTful endpoint structure following Rails conventions
   - Comprehensive error handling with rescue_from
   - Status code consistency (use Rails symbols: `:ok`, `:created`, `:unprocessable_entity`)
   - Clear response schemas documented with Rswag

2. **Frontend Development**

   - Hotwire (Turbo 8 + Stimulus 3.2+) for interactive UI
   - Server-rendered HTML with progressive enhancement
   - Turbo Streams for real-time updates via ActionCable
   - ViewComponent for reusable UI components
   - Tailwind CSS v4 for styling (Catppuccin Macchiato theme)
   - Responsive design
   - WCAG 2.1 AA accessibility compliance

3. **Performance**

   - Use Sidekiq for background processing
   - Efficient task distribution with proper queueing
   - Database query optimization (includes, preload, eager_load)
   - Fragment and Russian doll caching
   - Resource monitoring with Bullet gem in development

## Testing and Validation

1. **Testing Levels**

   - **Model specs**: Test validations, associations, scopes, and business logic
   - **Request specs**: Test API endpoints with Rswag contract testing
   - **System specs**: Full user workflows with Capybara
   - **Job specs**: Background job processing with Sidekiq testing mode
   - **Component specs**: ViewComponent unit tests
   - Performance benchmarking with RSpec benchmarking tools

2. **Quality Assurance**

   - **RuboCop**: Ruby code linting with Rails Omakase configuration
   - **Brakeman**: Security vulnerability scanning
   - **Bundler Audit**: Dependency security checking
   - **SimpleCov**: Code coverage measurement (target 90%+)
   - **Rswag**: API documentation and contract testing
   - **ERB Lint**: Template linting

3. **Testing Tools**

   - RSpec for all testing
   - FactoryBot for test data
   - Faker for realistic fake data
   - VCR for HTTP interaction recording
   - Capybara for browser-based system tests
   - Selenium/Cuprite for JavaScript testing
