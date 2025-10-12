# Requirements Document: CipherSwarm V2 Upgrade

**Version**: 2.0\
**Status**: Draft\
**Author(s)**: UncleSp1d3r\\

---

## Table of Contents

[TOC]

---

## 🪪 Introduction & Scope

### Project Overview

- **Project Description and Purpose**\
  CipherSwarm is a distributed password cracking management system designed for efficiency, scalability, and airgapped networks. The V2 upgrade enhances the existing Rails platform to coordinate multiple hashcat instances across different machines with improved real-time monitoring, enhanced user experience, and expanded collaboration features.

- **Project Goals and Objectives**\\

  - Enable distributed hashcat cracking across multiple machines with centralized coordination
  - Provide modern, user-friendly web interface for campaign and attack management
  - Support offline-first operations in airgapped environments
  - Maintain compatibility with existing agent infrastructure while modernizing the platform
  - Deliver comprehensive monitoring and real-time progress tracking
  - Support role-based access control and multi-project environments

- **Target Audience and Stakeholders**\
  **Red Team Operators**: Primary users conducting password audits and penetration testing

  - **Blue Team Analysts**: Security professionals analyzing password complexity and patterns
  - **Infrastructure Administrators**: IT personnel managing and maintaining the distributed cracking infrastructure
  - **Project Managers**: Oversight personnel tracking progress and resource utilization

- **Project Boundaries and Limitations**\\

  - Only supports hashcat as the cracking engine (no John the Ripper or other tools)
  - Designed for trusted LAN environments, not Internet-facing deployments
  - Requires high-speed, reliable network connections between agents
  - Not intended for anonymous or untrusted client connections

### Data Models & Relationships

- **Project**: Top-level boundary; isolates agents, campaigns, hash lists, users
- **Campaign**: Group of attacks targeting a hash list; belongs to one project
- **Attack**: Cracking config (mode, rules, masks, charsets); belongs to one campaign
- **Task**: Unit of work assigned to an agent; belongs to one attack
- **HashList**: Set of hashes; linked to campaigns (many-to-one)
- **HashItem**: Individual hash; can belong to many hash lists (many-to-many)
- **Agent**: Registered client; reports benchmarks, maintains heartbeat
- **CrackResult**: Record of a cracked hash; links attack, hash item, agent
- **AgentError**: Fault reported by agent; always belongs to one agent, may link to attack
- **Session**: Tracks task execution lifecycle
- **Audit**: Log of user/system actions
- **User**: Authenticated entity; role- and project-scoped
- **AttackResourceFile**: Reusable cracking resources (wordlists, rules, masks, charsets)

#### Relationships

- Project has many Campaigns; Campaign belongs to one Project
- User may belong to many Projects; Project may have many Users (many-to-many)
- Campaign has many Attacks; Attack belongs to one Campaign
- Attack has one or more Tasks; Task belongs to one Attack
- Campaign is associated with a single HashList; HashList can be associated with many Campaigns (many-to-one)
- HashList has many HashItems; HashItem can belong to many HashLists (many-to-many)
- CrackResult is associated with one Attack, one HashItem, and one Agent
- AgentError always belongs to one Agent, may be associated with one Attack
- Join tables (e.g., AgentsProjects) enforce multi-tenancy and cross-linking

### Scope Definition

- **In-scope Features and Functionality**

  - Platform upgrade to Rails 8.0+ with modern asset pipeline (Propshaft)
  - UI modernization with Tailwind CSS v4 and enhanced ViewComponent architecture
  - Enhanced agent API maintaining full v1 contract compatibility
  - Modern Web UI with real-time updates via Turbo 8 Streams and comprehensive campaign management
  - Enhanced testing coverage with RSpec system tests and API contract testing
  - Resource management with ActiveStorage integration and direct uploads
  - Hash type detection and automated wordlist generation
  - Campaign templates with import/export capabilities
  - Enhanced role-based access control with project-level isolation and persona support
  - Deployment modernization with Kamal 2 and zero-downtime deployments

- **Out-of-scope Items**

  - Support for cracking tools other than hashcat
  - Internet-facing or cloud-based deployments
  - Advanced machine learning or AI-based attack strategies
  - Integration with external identity providers (beyond basic auth)

- **Success Criteria and Acceptance Criteria**

  - All existing v1 agents can connect and operate without modification
  - Enhanced Web UI provides extended functionality while maintaining familiar workflows
  - System can handle distributed workloads across 10+ agents simultaneously
  - RSpec system tests and API contract tests provide comprehensive coverage
  - Performance meets or exceeds current baseline measurements

- **Timeline and Milestones**

  - **Milestone 0**: Rails 8 & Tailwind CSS Migration (Weeks 1-6)
  - **Milestone 1**: Platform Alignment & Foundations (Weeks 5-8)
  - **Milestone 2**: Authentication & Project Context (Weeks 7-11)
  - **Milestone 3**: Real-Time Operations Dashboard (Weeks 9-14)
  - **Milestone 4**: Campaign & Attack Experience Overhaul (Weeks 12-18)
  - **Milestone 5**: Agent & Task Distribution Enhancements (Weeks 16-22)
  - **Milestone 6**: Reporting, Collaboration, and Ops Hardening (Weeks 20-26)

### Context and Background

- **Business Context and Justification**

  Existing Ruby on Rails system provides a solid foundation that requires modernization. Rails 7.1 reached end-of-life on October 1, 2025, necessitating an upgrade to Rails 8.0+ for continued security support. The v2 upgrade delivers new capabilities, modern UI framework (Tailwind CSS), and improved deployment tooling while leveraging proven infrastructure and maintaining operational continuity.

- **Previous Work and Dependencies**

  - Existing v1 API contract that must be maintained for agent compatibility
  - Established user workflows and UI patterns that need preservation
  - Current production deployments that require seamless migration path

- **Assumptions and Constraints**

  - All client machines are trustworthy and under direct user control
  - Users belong to the same organization or project team
  - High-speed LAN connectivity between all system components
  - PostgreSQL 17+, Redis 7.2+, and file storage infrastructure available for deployment
  - Rails 8.0+ environment with modern Ruby 3.4.5 runtime

- **Risk Assessment Overview**

  - **Technical Risk**: Rails 8 upgrade complexity and Tailwind CSS migration require careful testing; Solid gems are mature but newer than traditional solutions
  - **Operational Risk**: Incremental rollout mitigates disruption; Kamal 2 provides zero-downtime deployments
  - **Performance Risk**: Rails 8 and PostgreSQL 17+ improvements expected to enhance performance; Tailwind CSS reduces bundle sizes
  - **User Risk**: Tailwind UI migration may require visual adjustments but maintains familiar workflows; Rails 8 authentication simpler than Devise

---

## ⚙️ Functional Requirements

### Core Features

- **F001**: Agent API must maintain full compatibility with v1 contract specification
- **F002**: Web UI must provide real-time updates via Turbo Streams and ActionCable
- **F003**: Campaign management with DAG-based attack ordering and execution
- **F004**: Resource management supporting wordlists, rules, masks, and charsets
- **F005**: Hash list management with automated hash type detection
- **F006**: Template system for campaign and attack reuse via JSON import/export
- **F007**: Role-based access control with admin, project admin, and user roles
- **F008**: Multi-project support with resource isolation and sharing controls
- **F009**: Agent monitoring with hardware configuration and performance tracking
- **F010**: Distributed task scheduling with automatic load balancing

### User Stories and Use Cases

1. **Campaign Lifecycle Management**: Red team operator creates a campaign, configures multiple attack strategies, launches distributed cracking across available agents, monitors progress in real-time, and exports results for reporting.

2. **Agent Fleet Management**: Infrastructure administrator registers new cracking agents, configures hardware settings, monitors performance and health status, and manages device assignments for optimal utilization.

3. **Resource Library Operations**: Security analyst uploads custom wordlists and rule files, organizes resources by project, shares resources across teams, and maintains version control through templates.

### Feature Priority Matrix

| Priority | Features                                                                                                |
| -------- | ------------------------------------------------------------------------------------------------------- |
| High     | Agent API compatibility, Campaign CRUD, Attack configuration, Real-time monitoring, Resource management |
| Medium   | Template import/export, Advanced agent controls, Performance analytics, Multi-project isolation         |
| Low      | Advanced visualization, Bulk operations, API rate limiting, Audit logging                               |

### Performance Requirements

- **API Response Time**: \<200ms for standard CRUD operations, \<500ms for complex queries
- **Real-time Updates**: Turbo Stream updates delivered within 1 second of backend state changes via ActionCable
- **Concurrent Users**: Support 50+ simultaneous web UI users without degradation
- **Agent Scalability**: Handle 100+ concurrent agents with task distribution
- **File Upload**: Support resource files up to 1GB with progress indication via ActiveStorage direct uploads
- **Database Performance**: Campaign queries with pagination under 100ms leveraging PostgreSQL 17+ features

---

## 🧑‍💻 User Interface Requirements

- **Web UI Framework**: Ruby on Rails 8.0+ with Hotwire (Turbo 8 + Stimulus 3.2+)
- **Component Library**: ViewComponent with Tailwind CSS v4 styling
- **Form Handling**: Rails form helpers with server-side validation and Turbo integration
- **Real-time Updates**: Turbo Streams and ActionCable (with Solid Cable option) for live data without polling
- **Authentication Flow**: Rails 8 authentication generator with session-based authentication
- **Responsive Design**: Mobile-first layouts with Tailwind responsive utilities
- **Theme Support**: Catppuccin Macchiato base with DarkViolet accent (#9400D3) via Tailwind configuration
- **Accessibility**: WCAG 2.1 AA compliance with keyboard navigation and screen reader support

---

## 🧪 Technical Specifications

### Language and Runtime

- **Backend**: Ruby 3.4.5 with Rails 8.0+ framework
- **Frontend**: Hotwire (Turbo 8+ + Stimulus 3.2+) with modern JavaScript
- **Database**: PostgreSQL 17+ with ActiveRecord ORM
- **File Storage**: ActiveStorage with S3-compatible backend support
- **Package Management**: Bundler for Ruby gems, pnpm for JavaScript packages (replacing Yarn)

### Core Libraries and Tooling

- **Authentication & Authorization**: Rails 8 authentication (replacing Devise), CanCanCan (authorization), Rolify (roles), Audited (audit logs)
- **Background Jobs**: Sidekiq 7.2+ with Sidekiq-Cron for scheduled tasks (evaluate Solid Queue for simpler deployments)
- **Caching**: Solid Cache for session/fragment caching with Redis backend
- **Real-time**: ActionCable with Solid Cable option, Turbo 8 Streams for live updates
- **UI Framework**: Tailwind CSS v4 with tailwindcss-rails gem, ViewComponent 4.0+ for reusable components
- **Asset Pipeline**: Propshaft (Rails 8 default) for modern asset delivery
- **Testing Stack**: RSpec with system tests, FactoryBot for test data, Rswag for API docs, SimpleCov for coverage
- **Build Tools**: Just for task automation, Kamal 2 for deployment
- **Development Tools**: RuboCop with Rails Omakase config, Brakeman for security, Bullet for N+1 detection

### CI/CD & Testing

- **Comprehensive Testing Strategy**:
  1. Model and service tests with RSpec unit tests
  2. Controller and request specs with API contract validation
  3. System tests with Capybara for full user workflows
  4. Background job tests with Sidekiq test mode
- **GitHub Actions**: Automated testing, RuboCop linting, Brakeman security scans
- **Docker Infrastructure**: Complete containerization for development and deployment
- **Test Coverage**: 90%+ code coverage with SimpleCov, comprehensive API documentation with Rswag

---

## 🔒 Security Requirements

- **Code Security**: No hardcoded secrets, comprehensive input validation, SQL injection prevention
- **Authentication**: Session-based authentication with secure cookie handling and CSRF protection
- **Authorization**: Role-based access control with project-level resource isolation
- **Data Security**: Hash lists and sensitive resources marked with appropriate access controls
- **Network Security**: Designed for trusted LAN environments with optional TLS termination
- **Operational Security**: No telemetry or external data transmission, audit logging for sensitive operations

---

## 🛠️ System Architecture

### System Components

- **Rails 8 Application**: Monolithic web application with REST API endpoints and modern asset pipeline
- **Hotwire Frontend**: Server-rendered views with Turbo 8 Streams and Stimulus 3.2+ controllers
- **PostgreSQL 17+ Database**: Primary data store with ActiveRecord connection pooling and advanced features
- **ActiveStorage**: File storage for resources with direct upload support and S3 compatibility
- **Solid Cache**: High-performance caching layer backed by database or Redis
- **Solid Cable**: ActionCable backend for real-time WebSocket connections
- **Sidekiq 7.2+ Workers**: Background job processing for async operations (with Solid Queue evaluation)
- **Thruster**: HTTP/2 reverse proxy for production deployments
- **Agent Network**: Distributed hashcat clients with heartbeat monitoring

### Data Flow Diagrams

```mermaid
graph TB
    subgraph "Presentation Layer"
        Views[Rails Views + Hotwire]
        TurboStreams[Turbo Streams]
        ActionCable[ActionCable Channels]
    end

    subgraph "Application Layer"
        Controllers[Rails Controllers]
        AgentAPI[Agent API v1]
        Services[Service Objects]
        Jobs[Sidekiq Jobs]
    end

    subgraph "Domain Layer"
        Models[ActiveRecord Models]
        StateMachines[AASM State Machines]
        Validators[Custom Validators]
    end

    subgraph "Infrastructure Layer"
        DB[(PostgreSQL)]
        Storage[(ActiveStorage)]
        Cache[(Redis)]
    end

    subgraph "External"
        Agents[Hashcat Agents]
    end

    Views --> Controllers
    Views <-- TurboStreams
    Views <-- ActionCable
    Agents --> AgentAPI
    Controllers --> Services
    AgentAPI --> Services
    Services --> Models
    Models --> DB
    Models --> Storage
    Jobs --> Models
    Jobs --> Cache
    ActionCable --> Cache
```

### Deployment

- **Container Strategy**: Docker with Kamal 2 for zero-downtime deployments, Thruster for HTTP/2 reverse proxy
- **Development**: Docker Compose with Rails, PostgreSQL 17+, Redis 7.2+, and Sidekiq containers
- **Production**: Kamal 2 orchestration with health checks, rolling deployments, and automatic rollbacks
- **Environment Support**: Development, staging, and production configurations with Rails credentials
- **Health Monitoring**: Comprehensive health checks with SidekiqAlive, Solid Cable, and database monitoring
- **Scaling Strategy**: Horizontal scaling for Rails application and Sidekiq workers via Kamal
- **Data Persistence**: Volume mounts for PostgreSQL, Redis, and ActiveStorage with automated backups

---

## ✅ Compliance with EvilBit Labs Standards

| Principle            | Implementation                                                                   |
| -------------------- | -------------------------------------------------------------------------------- |
| Offline-first        | Complete functionality in airgapped environments, no external dependencies       |
| Operator-focused     | CLI and web interfaces optimized for efficient workflows, minimal cognitive load |
| Transparent outputs  | JSON/CSV exports, comprehensive logging, clear progress indication               |
| Ethical distribution | MPL-2.0 license, no tracking, no data collection                                 |
| Sustainable design   | Modern architecture for maintainability, comprehensive test coverage             |

---

## 📎 Document Metadata

| Field           | Value       |
| --------------- | ----------- |
| Version         | 2.0         |
| Created Date    | 2025-01-07  |
| Last Modified   | 2025-10-12  |
| Author(s)       | UncleSp1d3r |
| Approval Status | Draft       |

---

## 📚 Glossary & References

- **Agent**: Distributed hashcat client that executes cracking tasks
- **Campaign**: Comprehensive unit of work focused on a single hash list
- **Attack**: Defined unit of hashcat work (mode, wordlist, rules, etc.)
- **Task**: Smallest unit of work assigned to an agent
- **DAG**: Directed Acyclic Graph for attack execution ordering
- **Turbo Streams**: Hotwire technology for real-time DOM updates over WebSocket
- **ActionCable**: Rails WebSocket framework for real-time features
- **Solid Cable**: Rails 8 database-backed ActionCable adapter
- **Solid Cache**: Rails 8 database-backed caching system
- **Solid Queue**: Rails 8 database-backed job queue (optional Sidekiq replacement)
- **Sidekiq**: Background job processing system for async operations
- **Kamal**: Zero-downtime deployment tool for containerized Rails applications
- **Propshaft**: Modern asset pipeline for Rails 8

**External References:**

- [Ruby on Rails 8 Guides](https://guides.rubyonrails.org/)
- [Hotwire Documentation](https://hotwired.dev/)
- [Tailwind CSS v4 Documentation](https://tailwindcss.com/docs)
- [ViewComponent Documentation](https://viewcomponent.org/)
- [Kamal Documentation](https://kamal-deploy.org/)
- [Hashcat Documentation](https://hashcat.net/hashcat/)
- [Sidekiq Documentation](https://github.com/sidekiq/sidekiq/wiki)
- [MPL-2.0 License](https://opensource.org/licenses/MPL-2.0)

**Internal References:**

- Upgrade Plan: `v1_upgrade_plan.md`
- API Documentation: `docs/api/overview.md`
- User Guide: `docs/user-guide/`
- Development Guide: `docs/development/`
