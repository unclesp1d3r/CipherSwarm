# CipherSwarm V2 Upgrade Implementation Tasks

**Version**: 2.1\
**Status**: Draft\
**Author(s)**: UncleSp1d3r\
**Date Created**: 2025-01-07\
**Last Modified**: 2025-10-12

---

## Table of Contents

[TOC]

---

## 🎯 Implementation Overview

This document provides a comprehensive breakdown of implementation tasks for the CipherSwarm V2 upgrade project. Tasks are organized by milestones following an incremental upgrade approach, enhancing the existing Ruby on Rails + Hotwire platform rather than a complete rewrite.

**Approach**: Incremental upgrade of existing Rails infrastructure\
**Current Rails Version**: 7.2\
**Target Rails Version**: 8.0+\
**Timeline**: 26 weeks across 7 milestones\
**Current Status**: Planning phase

---

## 📋 Milestone 0: Rails 8 & Tailwind CSS Migration (Weeks 1-6)

**Status**: 0% Complete 📋\
**Duration**: 6 weeks\
**Dependencies**: None\
**Priority**: Critical

### Rails 8 Upgrade

- [ ] **T001**: Audit current Rails 7.2 application for Rails 8 compatibility
- [ ] **T002**: Update Gemfile to Rails 8.0+ and resolve dependency conflicts
- [ ] **T003**: Run `rails app:update` and merge configuration changes
- [ ] **T004**: Replace Sprockets with Propshaft asset pipeline
- [ ] **T005**: Update Ruby version to 3.4.5 if needed
- [ ] **T006**: Test and fix breaking changes in controllers and models
- [ ] **T007**: Update RSpec tests for Rails 8 compatibility
- [ ] **T008**: Verify all existing features work with Rails 8

### PostgreSQL Upgrade

- [ ] **T009**: Upgrade PostgreSQL to version 17+ in development
- [ ] **T010**: Test database migrations with PostgreSQL 17
- [ ] **T011**: Update connection pooling configuration
- [ ] **T012**: Benchmark query performance improvements

### Tailwind CSS Migration

- [ ] **T013**: Install tailwindcss-rails gem and configure
- [ ] **T014**: Set up Tailwind CSS v4 with Catppuccin Macchiato theme
- [ ] **T015**: Configure DarkViolet (#9400D3) accent color
- [ ] **T016**: Create Tailwind component library structure
- [ ] **T017**: Migrate Bootstrap utility classes to Tailwind equivalents
- [ ] **T018**: Convert ViewComponents to use Tailwind classes
- [ ] **T019**: Update form styling to Tailwind-based design
- [ ] **T020**: Replace Bootstrap JavaScript with Stimulus controllers
- [ ] **T021**: Remove Bootstrap dependencies once migration complete
- [ ] **T022**: Update responsive breakpoints and mobile layouts

### Package Management

- [ ] **T023**: Migrate from Yarn to pnpm for JavaScript packages
- [ ] **T024**: Update package.json scripts for new build process
- [ ] **T025**: Configure Propshaft for CSS and JS bundling

---

## 📋 Milestone 1: Platform Alignment & Foundations (Weeks 5-8)

**Status**: 0% Complete 📋\
**Duration**: 4 weeks\
**Dependencies**: Milestone 0 (overlapping)\
**Priority**: High

### Rails Dependencies Upgrade

- [ ] **T026**: Upgrade Hotwire Turbo to version 8+
- [ ] **T027**: Upgrade Stimulus to version 3.2+
- [ ] **T028**: Update Sidekiq to version 7.2+
- [ ] **T029**: Ensure all gems compatible with Rails 8
- [ ] **T030**: Update development tools (RuboCop, Brakeman, etc.)

### Observability & Monitoring

- [ ] **T031**: Install and configure Solid Cache for session storage
- [ ] **T032**: Evaluate Solid Cable for ActionCable backend
- [ ] **T033**: Set up structured logging with Lograge
- [ ] **T034**: Configure performance monitoring baseline
- [ ] **T035**: Add rack-trace for request tracing
- [ ] **T036**: Set up Bullet for N+1 query detection in development

### Security Hardening

- [ ] **T037**: Review and update Devise session configuration
- [ ] **T038**: Implement configurable session timeouts
- [ ] **T039**: Review remember-me token security
- [ ] **T040**: Audit CSRF protection implementation
- [ ] **T041**: Update Content Security Policy headers
- [ ] **T042**: Run Brakeman security scan and address findings

### Caching Strategy

- [ ] **T043**: Configure ability caching with proper invalidation
- [ ] **T044**: Implement role change cache invalidation hooks
- [ ] **T045**: Set up project membership cache management
- [ ] **T046**: Configure Redis connection pooling
- [ ] **T047**: Test cache performance under load

### Data Model Alignment

- [ ] **T048**: Create migration to rename `attacks.type` column to `attacks.hash_type`
- [ ] **T049**: Update Attack model annotations and indexes for `hash_type`
- [ ] **T050**: Update all API serializers to use `hash_type` field name
- [ ] **T051**: Update test factories and specs to use `hash_type`
- [ ] **T052**: Run comprehensive grep to verify no lingering `type` references in attack context

---

## 📋 Milestone 2: Authentication & Project Context (Weeks 7-11)

**Status**: 0% Complete 📋\
**Duration**: 5 weeks\
**Dependencies**: Milestone 1 (overlapping)\
**Priority**: High

### Rails 8 Authentication Migration

- [ ] **T053**: Evaluate Rails 8 authentication generator
- [ ] **T054**: Plan migration path from Devise to Rails 8 auth
- [ ] **T055**: Implement Rails 8 authentication scaffolding
- [ ] **T056**: Migrate user sessions to new authentication system
- [ ] **T057**: Update password reset flow
- [ ] **T058**: Migrate email confirmation if needed
- [ ] **T059**: Update authentication tests

### Project Context Implementation

- [ ] **T060**: Create CurrentProject session helper
- [ ] **T061**: Build project switcher UI component (Turbo modal)
- [ ] **T062**: Implement Stimulus controller for project selection
- [ ] **T063**: Add project context to navigation bar
- [ ] **T064**: Update session management for active project
- [ ] **T065**: Filter all queries by active project scope

### Enhanced Authorization

- [ ] **T066**: Extend Rolify with new persona roles (Red, Blue, Infra, PM)
- [ ] **T067**: Update CanCanCan Ability rules for new personas
- [ ] **T068**: Implement project-level permission boundaries
- [ ] **T069**: Add ability tests for all persona combinations
- [ ] **T070**: Update navigation based on user roles
- [ ] **T071**: Create persona-specific dashboard views

### Project Scoping

- [ ] **T072**: Update Campaign model queries for project filtering
- [ ] **T078**: Update Attack model queries for project filtering
- [ ] **T079**: Update Agent model queries for project filtering
- [ ] **T080**: Update Resource queries for project filtering
- [ ] **T081**: Implement project isolation tests
- [ ] **T082**: Add project context to Turbo broadcasts

---

## 📋 Milestone 3: Real-Time Operations Dashboard (Weeks 9-14)

**Status**: 0% Complete 📋\
**Duration**: 6 weeks\
**Dependencies**: Milestone 2 (overlapping)\
**Priority**: High

### ActionCable & Turbo Streams Infrastructure

- [ ] **T078**: Configure ActionCable with Solid Cable backend
- [ ] **T079**: Set up ActionCable channels for dashboard updates
- [ ] **T080**: Implement Turbo Stream broadcasting for model changes
- [ ] **T081**: Create agent status update channel
- [ ] **T082**: Create task progress update channel
- [ ] **T083**: Create cracked hash notification channel
- [ ] **T084**: Test ActionCable scaling and performance

### Consolidated Operations Dashboard

- [ ] **T085**: Create dashboard controller and views
- [ ] **T086**: Build agent status card components with Tailwind
- [ ] **T087**: Build running tasks overview component
- [ ] **T088**: Build cracked hash feed component
- [ ] **T089**: Implement hash rate trending visualization
- [ ] **T090**: Add campaign throughput metrics
- [ ] **T091**: Create Stimulus controllers for live updates
- [ ] **T092**: Implement Chartkick integration for graphs

### Background Telemetry Collection

- [ ] **T093**: Create Sidekiq job for hash rate aggregation
- [ ] **T094**: Create Sidekiq job for agent health scoring
- [ ] **T095**: Implement 8-hour trend calculation job
- [ ] **T096**: Store telemetry rollups in Redis/PostgreSQL
- [ ] **T097**: Optimize telemetry queries for dashboard
- [ ] **T098**: Add caching for dashboard statistics

### UpdateStatusJob Enhancement

- [ ] **T099**: Enhance UpdateStatusJob to publish structured payloads
- [ ] **T100**: Add Turbo Stream broadcasts to status updates
- [ ] **T101**: Implement batch status update processing
- [ ] **T102**: Add error handling and retry logic
- [ ] **T103**: Test status job performance under load

---

## 📋 Milestone 4: Campaign & Attack Experience Overhaul (Weeks 12-18)

**Status**: 0% Complete 📋\
**Duration**: 7 weeks\
**Dependencies**: Milestone 3 (overlapping)\
**Priority**: High

### Campaign Wizard Implementation

- [ ] **T104**: Design multi-step campaign wizard flow
- [ ] **T105**: Implement Turbo Frame-based wizard navigation
- [ ] **T106**: Create campaign metadata form step (with Tailwind)
- [ ] **T107**: Create hash list upload step with direct uploads
- [ ] **T108**: Create attack configuration step
- [ ] **T109**: Add sensitivity flags and project tagging
- [ ] **T110**: Implement DAG toggle in wizard
- [ ] **T111**: Add wizard validation and error handling
- [ ] **T112**: Test wizard with various campaign types

### DAG-Based Attack Ordering

- [ ] **T113**: Add predecessor relationship to Attack model
- [ ] **T114**: Create attack dependency adjacency table
- [ ] **T115**: Implement DAG validation (no cycles)
- [ ] **T116**: Build attack ordering UI with drag-and-drop (Stimulus)
- [ ] **T117**: Visualize attack dependencies in UI
- [ ] **T118**: Update Task scheduling to respect dependencies
- [ ] **T119**: Add dependency resolution service object
- [ ] **T120**: Test DAG execution with various configurations

### Attack Management Enhancement

- [ ] **T121**: Create attack ordering interface
- [ ] **T122**: Implement drag-and-drop with SortableJS + Stimulus
- [ ] **T123**: Add attack priority field to model
- [ ] **T124**: Update attack list views with Tailwind styling
- [ ] **T125**: Add attack cloning functionality
- [ ] **T126**: Implement attack templates
- [ ] **T127**: Add attack pause/resume controls

### Campaign Metadata

- [ ] **T128**: Add sensitivity_level field to Campaign
- [ ] **T129**: Add campaign tags functionality
- [ ] **T130**: Implement campaign search and filtering
- [ ] **T131**: Add campaign notes and descriptions
- [ ] **T132**: Create campaign timeline view

---

## 📋 Milestone 5: Agent & Task Distribution Enhancements (Weeks 16-22)

**Status**: 0% Complete 📋\
**Duration**: 7 weeks\
**Dependencies**: Milestone 4 (overlapping)\
**Priority**: High

### Agent API Enhancements

- [ ] **T133**: Expand v1 agent API for configuration endpoints
- [ ] **T134**: Add hash type allowances endpoint
- [ ] **T135**: Add wordlist manifest endpoint
- [ ] **T136**: Implement agent capability reporting
- [ ] **T137**: Add GPU inventory reporting
- [ ] **T138**: Enhance heartbeat with performance data
- [ ] **T139**: Update API documentation with Rswag

### DAG-Aware Task Scheduling

- [ ] **T140**: Create task scheduling service object
- [ ] **T141**: Implement dependency-aware task assignment
- [ ] **T142**: Add agent capability matching logic
- [ ] **T143**: Implement campaign priority handling
- [ ] **T144**: Add task queue management
- [ ] **T145**: Handle task transitions (accept/run/complete)
- [ ] **T146**: Add task retry and error handling

### Background Jobs for Agent Management

- [ ] **T147**: Create benchmarking refresh job
- [ ] **T148**: Create agent health scoring job
- [ ] **T149**: Create queue length monitoring job
- [ ] **T150**: Implement stale agent detection job
- [ ] **T151**: Add agent performance analytics job
- [ ] **T152**: Configure Sidekiq-Cron schedules

### Load Balancing & Distribution

- [ ] **T153**: Implement agent load calculation
- [ ] **T154**: Add dynamic task assignment based on load
- [ ] **T155**: Implement task rebalancing logic
- [ ] **T156**: Add agent blacklist/whitelist per project
- [ ] **T157**: Create agent assignment strategies
- [ ] **T158**: Test distribution under various loads

---

## 📋 Milestone 6: Reporting, Collaboration, and Ops Hardening (Weeks 20-26)

**Status**: 0% Complete 📋\
**Duration**: 7 weeks\
**Dependencies**: Milestone 5 (overlapping)\
**Priority**: Medium

### Reporting System

- [ ] **T159**: Create reporting jobs for cracked password stats
- [ ] **T160**: Build Blue Team trend report dashboard
- [ ] **T161**: Build PM timeline view
- [ ] **T162**: Implement password pattern analysis
- [ ] **T163**: Add exportable reports (CSV/JSON)
- [ ] **T164**: Create report scheduling functionality
- [ ] **T165**: Add saved report views

### Collaboration Features

- [ ] **T166**: Create project activity feed using ActionCable
- [ ] **T167**: Implement campaign comments system
- [ ] **T168**: Add @mentions in comments
- [ ] **T169**: Create notification system for updates
- [ ] **T170**: Add team collaboration dashboard
- [ ] **T171**: Implement shared campaign notes

### Deployment with Kamal 2

- [ ] **T172**: Install and configure Kamal 2
- [ ] **T173**: Create Kamal deployment configuration
- [ ] **T174**: Set up zero-downtime deployment pipeline
- [ ] **T175**: Configure Thruster HTTP/2 proxy
- [ ] **T176**: Implement health checks for deployments
- [ ] **T177**: Test rolling deployment strategy
- [ ] **T178**: Configure automatic rollbacks

### Production Hardening

- [ ] **T179**: Configure Sidekiq scaling strategy
- [ ] **T180**: Set up PostgreSQL 17 replication
- [ ] **T181**: Implement automated backups
- [ ] **T182**: Configure monitoring (Prometheus/Skylight)
- [ ] **T183**: Set up log aggregation
- [ ] **T184**: Create runbook documentation
- [ ] **T185**: Perform security audit with Brakeman
- [ ] **T186**: Load test production configuration

### Testing & Quality Assurance

- [ ] **T187**: Expand RSpec system test coverage
- [ ] **T188**: Add integration tests for new features
- [ ] **T189**: Perform regression testing
- [ ] **T190**: Load test with 100+ agents
- [ ] **T191**: Security penetration testing
- [ ] **T192**: Accessibility audit (WCAG 2.1 AA)
- [ ] **T193**: Performance benchmarking vs baseline

---

## 🎯 Critical Path Tasks

The following tasks are on the critical path and must be completed sequentially:

### Milestone 0 Critical Tasks (Weeks 1-6)

1. **T001-T008**: Rails 8 upgrade - Mandatory for security (Rails 7.1 EOL)
2. **T013-T022**: Tailwind CSS migration - UI modernization foundation
3. **T009-T012**: PostgreSQL 17 upgrade - Database performance improvements

### Milestone 1 Critical Tasks (Weeks 5-8)

1. **T026-T030**: Hotwire/Sidekiq upgrades - Platform alignment
2. **T031-T032**: Solid Cache/Cable setup - Real-time infrastructure
3. **T037-T042**: Security hardening - Production readiness
4. **T048-T052**: Data model alignment - Fix `type` to `hash_type` naming inconsistency

### Milestone 2 Critical Tasks (Weeks 7-11)

1. **T053-T059**: Rails 8 authentication migration - Core security feature
2. **T060-T065**: Project context implementation - Multi-tenancy foundation
3. **T066-T071**: Enhanced authorization - Role-based access control

### Milestone 3 Critical Tasks (Weeks 9-14)

1. **T078-T084**: ActionCable/Turbo infrastructure - Real-time foundation
2. **T085-T092**: Operations dashboard - Primary user interface
3. **T093-T098**: Telemetry collection - Performance monitoring

### Milestone 4 Critical Tasks (Weeks 12-18)

1. **T104-T112**: Campaign wizard - Enhanced user experience
2. **T113-T120**: DAG implementation - Advanced workflow management
3. **T121-T127**: Attack management - Core functionality

### Milestone 5 Critical Tasks (Weeks 16-22)

1. **T133-T139**: Agent API enhancements - Agent integration
2. **T140-T146**: DAG-aware task scheduling - Core distribution logic
3. **T153-T158**: Load balancing - Multi-agent efficiency

---

## 🔧 Implementation Notes

### Rails 8 Migration Considerations

- **Sprockets to Propshaft**: Audit all asset references and update import paths
- **Devise to Rails 8 Auth**: Plan gradual migration with feature flags for safety
- **Bootstrap to Tailwind**: Component-by-component migration minimizes risk
- **Solid Gems Evaluation**: Test Solid Cache/Cable in staging before production

### Data Model Alignment (NEW - Milestone 1)

- **Attack Model `type` → `hash_type` Rename**: The spec requires `hash_type` but the current DB schema uses `type` column
  - Create migration to rename `attacks.type` to `attacks.hash_type`
  - Update all model annotations, indexes, queries, and serializers
  - Comprehensive testing to ensure no breakage in attack creation/management
  - See `docs/v2_rewrite_implementation_plan/phase-1-core-infrastructure.md` for details

### Technical Debt Items

- **ActiveStorage Optimization**: Implement direct uploads for large files
- **N+1 Query Elimination**: Use Bullet gem findings to optimize queries
- **ActionCable Scaling**: Test WebSocket connections under high load
- **Agent API Performance**: Optimize v1 API endpoints for high agent counts

### Risk Mitigation

- **V1 Agent Compatibility**: Comprehensive regression testing with real agents
- **Rails 8 Compatibility**: Thorough testing of all models, controllers, and views
- **UI Migration**: Gradual Tailwind rollout with visual regression testing
- **Real-time Scaling**: Load test ActionCable with 100+ concurrent connections
- **Deployment Safety**: Kamal 2 rollback procedures tested and documented

### Dependencies and Constraints

- **External Dependencies**: hashcat binary availability on agent systems
- **Infrastructure Requirements**: PostgreSQL 17+, Redis 7.2+, S3-compatible storage
- **Network Requirements**: High-speed LAN connectivity for optimal performance
- **Security Constraints**: Airgap-friendly deployment with no external dependencies
- **Rails Version**: Must upgrade from 7.2 to 8.0+ (7.1 EOL Oct 1, 2025)

---

## 📊 Progress Tracking

### Milestone Completion Status

| Milestone   | Weeks | Status     | Completion % | Key Deliverables                             |
| ----------- | ----- | ---------- | ------------ | -------------------------------------------- |
| Milestone 0 | 1-6   | 📋 Pending | 0%           | Rails 8, Tailwind CSS, PostgreSQL 17         |
| Milestone 1 | 5-8   | 📋 Pending | 0%           | Platform upgrade, observability, security    |
| Milestone 2 | 7-11  | 📋 Pending | 0%           | Rails 8 auth, project context, authorization |
| Milestone 3 | 9-14  | 📋 Pending | 0%           | Real-time dashboard, ActionCable, telemetry  |
| Milestone 4 | 12-18 | 📋 Pending | 0%           | Campaign wizard, DAG, attack management      |
| Milestone 5 | 16-22 | 📋 Pending | 0%           | Agent API, DAG scheduling, load balancing    |
| Milestone 6 | 20-26 | 📋 Pending | 0%           | Reporting, collaboration, Kamal deployment   |

### Overall Project Status

- **Total Tasks**: 193
- **Completed**: 0 (0%)
- **In Progress**: 0 (0%)
- **Pending**: 193 (100%)

**Project Timeline**: 26 weeks with overlapping milestones\
**Estimated Start**: TBD\
**Estimated Completion**: TBD + 26 weeks

---

## 📋 Task Template

For new tasks, use this template:

```markdown
### Task ID: TXXX

**Title**: [Task Title]
**Milestone**: [Milestone Number]
**Priority**: [High/Medium/Low/Critical]
**Estimated Effort**: [Hours/Days/Weeks]
**Dependencies**: [Task IDs or Milestone requirements]
**Rails Component**: [Model/Controller/View/Job/Service/Component]
**Assignee**: [Developer name or TBD]

**Description**:
[Detailed description of the task]

**Acceptance Criteria**:
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

**Technical Notes**:
[Rails-specific implementation details, gem requirements, migration needs]

**Testing Requirements**:
- [ ] Unit tests (RSpec model/service specs)
- [ ] Integration tests (RSpec request specs)
- [ ] System tests (Capybara/RSpec)
- [ ] Manual QA checklist
```

---

## 📝 Change Log

| Date       | Version | Changes                                                   | Author      |
| ---------- | ------- | --------------------------------------------------------- | ----------- |
| 2025-10-12 | 2.1     | Updated for Rails V1 upgrade approach (188 tasks)         | UncleSp1d3r |
| 2025-01-07 | 2.0     | Initial task breakdown from Python rewrite implementation | UncleSp1d3r |

---

**Note**: This task breakdown follows the incremental Rails V1 upgrade approach outlined in `v1_upgrade_plan.md` and `requirements.md`. It replaces the previous Python/FastAPI rewrite plan with a pragmatic upgrade strategy that modernizes the existing Rails infrastructure while maintaining operational continuity.
