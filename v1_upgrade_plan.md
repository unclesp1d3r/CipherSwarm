# CipherSwarm V1 Upgrade Plan for Delivering V2 Goals

---

## Table of Contents

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=2 --minlevel=1 -->

- [CipherSwarm V1 Upgrade Plan for Delivering V2 Goals](#cipherswarm-v1-upgrade-plan-for-delivering-v2-goals)
  - [Table of Contents](#table-of-contents)
  - [1. Purpose and Scope](#1-purpose-and-scope)
  - [2. Baseline Assessment of the V1 Rails Application](#2-baseline-assessment-of-the-v1-rails-application)
  - [3. Gap Analysis Versus V2 User Stories](#3-gap-analysis-versus-v2-user-stories)
  - [4. Plan of Action & Milestones](#4-plan-of-action--milestones)
  - [5. Key Technical Considerations & Hurdles](#5-key-technical-considerations--hurdles)
  - [6. Testing & Quality Strategy](#6-testing--quality-strategy)
  - [7. Risk Register & Mitigations](#7-risk-register--mitigations)
  - [8. Success Criteria & Exit Checklist](#8-success-criteria--exit-checklist)
  - [Decision Summary](#decision-summary)

<!-- mdformat-toc end -->

## 1. Purpose and Scope

This document outlines how to deliver the updated CipherSwarm V2 user stories on top of the existing Ruby on Rails + Hotwire codebase instead of pursuing a ground-up Python rewrite. It inventories the current V1 (Rails) capabilities, maps gaps against the V2 requirements, and breaks down a sequenced plan of action with milestones, risks, and validation strategies for achieving the target experience while retaining the current stack.

## 2. Baseline Assessment of the V1 Rails Application

### 2.1 Domain Modeling & Persistence

- **Campaign orchestration already exists** with rich priority management, soft deletes, Turbo-driven broadcasts, and callbacks that pause/resume lower-priority work when higher-priority campaigns enter the system.【F:app/models/campaign.rb†L6-L143】
- **Agents expose a state machine, advanced configuration payloads, and project associations**; they already heartbeat into the system and broadcast Turbo refreshes, providing a strong foundation for richer agent lifecycle management.【F:app/models/agent.rb†L6-L141】
- **Projects provide the grouping abstraction and broadcast hooks** needed for project scoping and multi-tenant filtering, while role assignments are handled by Rolify and audited for traceability.【F:app/models/project.rb†L6-L70】
- **Users authenticate with Devise, inherit role-based permissions via CanCanCan, and cache project membership lists**, giving us the building blocks for user personas and project-aware navigation.【F:app/models/user.rb†L6-L118】【F:app/models/ability.rb†L6-L69】
- **Tasks encapsulate attack execution state with a comprehensive state machine and status retention**, and Sidekiq-backed jobs already manage stale activity and campaign reprioritization (e.g., `UpdateStatusJob`).【F:app/models/task.rb†L6-L198】【F:app/jobs/update_status_job.rb†L6-L61】

### 2.2 APIs, UI, and Real-Time Behavior

- The routing layer already exposes campaign, attack, and resource CRUD plus a namespaced v1 agent API, giving us a clear place to expand authenticated JSON endpoints and project context selectors.【F:config/routes.rb†L295-L320】
- Hotwire Turbo broadcasts are already wired through Active Record models, meaning we can surface near–real-time updates by layering Turbo Streams/Stimulus dashboards rather than introducing new SSE plumbing.【F:app/models/campaign.rb†L124-L129】【F:app/models/agent.rb†L85-L141】
- ActionCable scaffolding exists (channels are present), but custom channels will be required to expose richer dashboards and live hash-crack feeds.

### 2.3 Operational Footprint

- Sidekiq is mounted in routes and jobs exist for regular housekeeping, so background orchestration for telemetry, reporting, and long-running calculations can stay within the existing job infrastructure.【F:config/routes.rb†L295-L320】【F:app/jobs/update_status_job.rb†L18-L61】
- Audited change tracking and cached project membership provide the compliance hooks needed for the V2 personas without altering the persistence model.【F:app/models/project.rb†L6-L70】【F:app/models/user.rb†L60-L118】

## 3. Gap Analysis Versus V2 User Stories

### 3.1 Authentication & Access Control

- **Project context selection (AC-002)**: V1 stores user–project links but lacks a first-class session-level “active project.” We need a UI flow (Turbo modal or page) plus session persistence and ability scoping to filter records by that active project.
- **Role differentiation** already exists (admin/basic) but does not cover the nuanced Red/Blue/Infra personas. We must extend Rolify roles and Ability rules to align with the new personas, add Devise navigation cues, and confirm multi-factor or stricter session policies where necessary.

### 3.2 Dashboard & Monitoring

- The current UI focuses on CRUD lists; there is no consolidated live operations dashboard. We must build Hotwire dashboards backed by ActionCable/Turbo Streams that aggregate agent health, campaign throughput, and cracked hash feed—leveraging existing model broadcasts but consolidating them into SSE-style dashboards.
- Hash rate trending and historical telemetry require new background collectors (e.g., Sidekiq jobs) that materialize aggregated stats into Redis/Postgres for quick rendering.

### 3.3 Campaign & Attack Management

- The campaign wizard does not exist—current flows rely on standard Rails forms. We need a multi-step Turbo wizard that handles file uploads, metadata, DAG toggles, and transitions into attack configuration.
- Attack configuration is granular but lacks drag/drop ordering or advanced combos; Stimulus controllers plus persisted ordering fields must be introduced while reusing the `Attack` model and state machine logic.

### 3.4 Agent & Task Distribution

- Agents heartbeat and update status, but advanced queueing (task reservations, load balancing) for DAG-controlled campaigns is not fully fleshed out. We need scheduling services that respect campaign priority, agent capability (hash-type compatibility, GPU inventory), and DAG dependencies.
- Agent configuration API responses must expand beyond basic authentication to deliver configuration bundles (hash modes, dictionaries, masks) that align with the new persona workflows.【F:app/controllers/api/v1/base_controller.rb†L6-L92】

### 3.5 Reporting, Analytics, and Collaboration

- V1 lacks aggregated reporting for Blue Team analysts (password patterns, exportable dashboards). We need reporting jobs to summarize crack results, plus UI components for saved views.
- Collaboration features (comments, project timeline) are absent; we must introduce Turbo Streams or ActionCable-driven activity feeds tied to projects and campaigns.

### 3.6 Deployment & Ops

- Containerization exists but must be hardened with production-ready Sidekiq/Redis setups, environment configuration for telemetry exporters, and infrastructure-as-code for scaling Rails/Sidekiq nodes instead of the planned Python microservices.

## 4. Plan of Action & Milestones

The plan assumes a 4–5 month delivery window with overlapping tracks. Each milestone ends with reviewable demos and regression suites.

### Milestone 1 — Platform Alignment & Foundations (Weeks 1–4)

- Upgrade Rails/Hotwire dependencies to latest compatible versions and ensure Turbo Streams are consistently enabled across models emitting real-time updates.
- Introduce system-level observability primitives (Lograge, rack-trace) to support upcoming dashboards.
- Harden Devise session security (configurable timeouts, remember-me review) and ensure ability caching invalidates on role or project changes.
- Deliverables: dependency upgrade PRs, CI smoke tests, baseline performance metrics.

### Milestone 2 — Authentication & Project Context (Weeks 3–7)

- Build a project switcher UI (Turbo modal) tied to a new `CurrentProject` session helper and Stimulus controller to enforce AC-002.
- Extend `Ability` rules to support new personas (Red, Blue, Infra, PM) with role-specific actions while retaining admin overrides.【F:app/models/ability.rb†L30-L69】
- Update navigation and Devise flows to reflect persona-specific dashboards; ensure agents and campaigns are filtered by active project scopes (`Project`, `Campaign`, `Agent` relations).【F:app/models/project.rb†L56-L70】【F:app/models/campaign.rb†L103-L119】【F:app/models/agent.rb†L69-L88】
- Deliverables: Working project selector, updated authorization specs, regression pass on existing CRUD flows.

### Milestone 3 — Real-Time Operations Dashboard (Weeks 5–10)

- Create a consolidated dashboard controller/view that streams agent status, running tasks, and cracked hash events via Turbo Streams and ActionCable channels.
- Instrument `UpdateStatusJob` and related jobs to publish structured status payloads; store rollups for 8-hour hash-rate trends queried by the dashboard.【F:app/jobs/update_status_job.rb†L18-L61】
- Build Stimulus components for graphs (e.g., Chartkick) and ensure Hotwire updates do not over-fetch.
- Deliverables: Live dashboard demo matching DM-001/DM-002 acceptance criteria, performance budget doc, cable scaling tests.

### Milestone 4 — Campaign & Attack Experience Overhaul (Weeks 8–14)

- Implement a Turbo-powered multi-step campaign wizard, reusing existing `Campaign` associations and validations while adding metadata fields (sensitivity flags, DAG toggle).【F:app/models/campaign.rb†L103-L170】
- Add DAG-aware scheduling: extend `Campaign`/`Attack` models with predecessor relationships; update `Task` scheduling services to respect dependency resolution.【F:app/models/task.rb†L99-L198】
- Introduce attack ordering UI (Stimulus drag/drop) and persist ordering/priority in existing columns or new fields.
- Deliverables: Wizard walkthrough, DAG scheduler tests, updated attack management UI.

### Milestone 5 — Agent & Task Distribution Enhancements (Weeks 12–18)

- Expand the v1 agent API to expose configuration endpoints (hash type allowances, wordlist manifests) while leveraging existing token auth and heartbeat logic.【F:app/controllers/api/v1/base_controller.rb†L9-L92】【F:app/models/agent.rb†L157-L198】
- Build a scheduling service object (Rails service) that assigns tasks based on agent capability and campaign priority, integrating with `Task` state machine transitions (accept/run/complete).【F:app/models/task.rb†L113-L198】
- Implement background jobs for benchmarking refresh, agent health scoring, and queue length monitoring.
- Deliverables: API documentation (Rswag), agent integration tests, scheduling service coverage.

### Milestone 6 — Reporting, Collaboration, and Ops Hardening (Weeks 16–20)

- Add reporting jobs that roll up cracked password statistics and expose persona-specific dashboards (e.g., Blue Team trend reports, PM timeline views) using Turbo Streams for updates.
- Introduce project activity feeds leveraging ActionCable, hooking into Audited callbacks on `Project`, `Campaign`, and `Task` models.【F:app/models/project.rb†L56-L68】【F:app/models/campaign.rb†L124-L143】【F:app/models/task.rb†L167-L198】
- Harden deployment: finalize Docker images, configure Sidekiq scaling, add monitoring dashboards (Prometheus exporters or Skylight) aligned with Rails infrastructure.
- Deliverables: Reporting UI, collaboration timeline, documented deployment runbooks.

## 5. Key Technical Considerations & Hurdles

- **Session & Authorization Complexity**: Maintaining an active project context requires careful coordination between Devise session storage, CanCanCan ability evaluation, and caching of `user.all_project_ids`. We must invalidate caches whenever project roles change to avoid stale permission sets.【F:app/models/user.rb†L95-L109】【F:app/models/ability.rb†L30-L69】
- **Real-Time Scaling**: Turbo broadcasts already trigger DOM updates, but consolidating thousands of agent/task updates into a single dashboard needs throttling, background fan-out via Redis, and ActionCable channel partitioning to avoid Hotwire stream overload.【F:app/models/agent.rb†L85-L141】【F:app/jobs/update_status_job.rb†L18-L61】
- **DAG Scheduling in Rails**: Implementing DAG execution without rewriting the task scheduler means adding adjacency tables and ensuring the Sidekiq workers respect dependencies before transitioning `Task` state machines. We must avoid blocking operations inside jobs and rely on database checks.
- **File Handling in Wizards**: Campaign creation requires multi-step file uploads (hashlists, dictionaries). We should leverage ActiveStorage direct uploads and ensure wizard steps handle validation rollbacks gracefully.
- **Reporting Performance**: Aggregating cracked hashes and telemetry will stress Postgres; we may need materialized views or incremental rollups triggered by Sidekiq jobs to keep dashboards responsive.

## 6. Testing & Quality Strategy

- Extend existing RSpec suites with system tests for project selection, dashboard streaming, and campaign wizards. Tests should simulate Turbo Streams to ensure DOM updates render correctly.
- Use Rswag to document the expanded agent API endpoints and enforce contract tests.
- Introduce Sidekiq/ActionCable integration tests to validate real-time updates and load test under simulated agent churn.
- Maintain regression coverage across Devise flows, ensuring role-permission boundaries remain intact with persona expansion.

## 7. Risk Register & Mitigations

| Risk                                                           | Impact | Likelihood | Mitigation                                                                                             |
| -------------------------------------------------------------- | ------ | ---------- | ------------------------------------------------------------------------------------------------------ |
| Turbo/ActionCable saturation from high-frequency agent updates | High   | Medium     | Batch updates via Redis pub/sub, throttle broadcasts, use background aggregator jobs                   |
| Complex DAG scheduler introduces race conditions               | High   | Medium     | Model state transitions with database constraints, comprehensive unit/integration tests, feature flags |
| Persona-specific authorization regressions                     | Medium | Medium     | Pair ability changes with contract tests and CanCanCan policies; manual QA by each persona             |
| Reporting workloads degrade Postgres performance               | Medium | Medium     | Offload to read replicas/materialized views, use Sidekiq scheduled jobs, cache results                 |
| Deployment drift when scaling Sidekiq                          | Medium | Low        | IaC templates, environment parity testing, use SidekiqAlive for health checks                          |

## 8. Success Criteria & Exit Checklist

- All V2 user stories have mapped acceptance criteria to Rails features with demos in staging.
- Real-time dashboards update within target latency (\<5s) under expected agent/task load.
- Authorization matrix validated for all personas across multiple projects.
- DAG-enabled campaigns run end-to-end with automated tests covering happy path and failure recovery.
- Reporting dashboards and exports deliver actionable insights without manual database queries.
- Dockerized deployment pipeline ready with documented rollback and monitoring procedures.

---

## Decision Summary

Upgrading the Rails/Hotwire stack provides a viable path to the V2 goals by reusing mature domain models, Turbo real-time features, and Sidekiq infrastructure. The milestones above balance foundational hardening with iterative feature delivery, minimizing rewrite risk while delivering the desired user experiences.
