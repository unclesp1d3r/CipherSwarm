# CipherSwarm Developer Guide

CipherSwarm is a distributed password cracking management system built with FastAPI and SvelteKit. It coordinates multiple agents running hashcat to efficiently distribute password cracking tasks across a network of machines.

---

## Table of Contents

1. [Project Architecture & Core Concepts](#project-architecture--core-concepts)
2. [UI Style & Component Guide](#ui-style--component-guide)
3. [Code Style & Structure](#code-style--structure)
4. [API Design & Conventions](#api-design--conventions)
5. [Testing & Quality Assurance](#testing--quality-assurance)
6. [Tooling & Dependency Management](#tooling--dependency-management)
7. [Security Best Practices](#security-best-practices)
8. [Frontend & UX Guidelines](#frontend--ux-guidelines)
9. [Git & Commit Standards](#git--commit-standards)
10. [Protected Zones](#protected-zones)

---

## 1. Project Architecture & Core Concepts

### Project Overview

-   **Distributed password cracking** with FastAPI, SvelteKit, and Hashcat agents
-   **Multi-versioned API**: v1 (legacy, OpenAPI 3.0.1, strict contract), v2 (FastAPI-native, idiomatic, breaking changes allowed)
-   **Backend stack**: FastAPI, SQLAlchemy, Celery, Cashews, MinIO, Redis, Nginx
-   **Frontend**: SvelteKit, JSON API, Flowbite Svelte, DaisyUI

### Data Models & Relationships

-   **Project**: Top-level boundary; isolates agents, campaigns, hash lists, users
-   **Campaign**: Group of attacks targeting a hash list; belongs to one project
-   **Attack**: Cracking config (mode, rules, masks, charsets); belongs to one campaign
-   **Task**: Unit of work assigned to an agent; belongs to one attack
-   **HashList**: Set of hashes; linked to campaigns (many-to-one)
-   **HashItem**: Individual hash; can belong to many hash lists (many-to-many)
-   **Agent**: Registered client; reports benchmarks, maintains heartbeat
-   **CrackResult**: Record of a cracked hash; links attack, hash item, agent
-   **AgentError**: Fault reported by agent; always belongs to one agent, may link to attack
-   **Session**: Tracks task execution lifecycle
-   **Audit**: Log of user/system actions
-   **User**: Authenticated entity; role- and project-scoped
-   **Relationships**:
    -   Project has many Campaigns; Campaign belongs to one Project
    -   User may belong to many Projects; Project may have many Users (many-to-many)
    -   Campaign has many Attacks; Attack belongs to one Campaign
    -   Attack has one or more Tasks; Task belongs to one Attack
    -   Campaign is associated with a single HashList; HashList can be associated with many Campaigns (many-to-one)
    -   HashList has many HashItems; HashItem can belong to many HashLists (many-to-many)
    -   CrackResult is associated with one Attack, one HashItem, and one Agent
    -   AgentError always belongs to one Agent, may be associated with one Attack
    -   Join tables (e.g., AgentsProjects) enforce multi-tenancy and cross-linking

### API Interfaces & Router Mapping

-   **Agent API** (`/api/v1/client/*`):
    -   Endpoints: agents, attacks, tasks, crackers, configuration, authenticate
    -   Each resource in its own router file under `app/api/v1/endpoints/agent/`
    -   Root-level endpoints grouped in `general.py`
-   **Web UI API** (`/api/v1/web/*`):
    -   Endpoints: campaigns, attacks, agents, dashboard
    -   Routers in `app/api/v1/endpoints/web/`
-   **Control API** (`/api/v1/control/*`):
    -   Endpoints: campaigns, attacks, agents, stats
    -   Routers in `app/api/v1/endpoints/control/`
-   **Shared Infrastructure API**: e.g., `/api/v1/users`, `/api/v1/resources/{id}/download`
    -   Endpoints used by all major interfaces, implemented in shared routers

### Agent, Attack, and Task Lifecycle

-   **Agent States**: `pending` → `active` → `stopped` → `error`
-   **Attack Modes**: dictionary, mask, hybrid, rule-based
-   **Task Lifecycle**: creation → assignment → progress → result → completion/abandonment
-   **Task Features**: keyspace distribution, progress tracking, real-time status, error handling

### Resource Storage & Security

-   **MinIO S3** for all static attack resources (wordlists, rules, masks, charsets)
-   **File organization**: UUID-based names, metadata for original filename/version
-   **Security**: Bucket policies, presigned URLs, role-based access, server-side encryption, TLS, virus scanning, file type verification
-   **Monitoring**: Access logs, usage metrics, error tracking, quotas
-   **Web UI requirements**: Direct file uploads, progress tracking, checksum verification, resource management, file preview, tagging, categorization
-   **MinIO Bucket Structure**:
    -   `wordlists/`: Dictionary attack word lists
    -   `rules/`: Hashcat rule files
    -   `masks/`: Mask pattern files
    -   `charsets/`: Custom charset definitions
    -   `temp/`: Temporary storage for uploads

### Docker, Deployment, and Scaling

#### Required Services (Docker Compose):

-   `app`: FastAPI application (Python 3.13, uv, health checks, graceful shutdown)
-   `db`: PostgreSQL 16+ (persistent volume, automated backups)
-   `redis`: Redis (session storage, rate limiting, task queue backend)
-   `minio`: MinIO (S3-compatible object storage for attack resources)
-   `nginx`: Nginx reverse proxy (SSL termination, static file serving)
-   _(Optional)_: Prometheus, Grafana, Node exporter, Cadvisor for monitoring

#### File/Directory Layout:

-   All service Dockerfiles under `docker/<service>/Dockerfile[.dev|.prod]`
-   Compose files: `docker-compose.yml`, `docker-compose.dev.yml`, `docker-compose.prod.yml` at project root
-   `.dockerignore` at project root; must exclude `.venv`, `node_modules`, test artifacts, and secrets

#### Dockerfile & Compose Conventions:

-   Use Python 3.13 base image for app, `uv` as package manager
-   Health checks for all long-running services
-   All containers run as non-root users
-   Multi-stage builds for app image
-   Expose only required ports
-   Use environment variables for all secrets/config
-   Named volumes for persistent data (db, redis, minio)
-   `depends_on` for service startup order
-   `.env` or `env.example` for environment variable documentation
-   All services must have restart policies set (`unless-stopped` or `always`)
-   Nginx mounts `./static` and `./certs` for static files and SSL

#### Security:

-   No hardcoded secrets in Dockerfiles or Compose
-   All secrets/configs injected via environment variables or secrets files
-   All images regularly scanned for vulnerabilities
-   Containers must run as non-root, with resource limits and read-only root where possible

#### Best Practices:

-   Use `.dockerignore` to reduce build context
-   Pin package versions
-   Clean up after installing packages
-   Use exec form of `CMD`/`ENTRYPOINT`
-   Set file permissions, configure timezone, set resource limits
-   Use health checks, automate builds, and integrate with CI/CD
-   Use container image scanners (e.g., Trivy, Clair)
-   Document Dockerfiles and images

#### Deployment & Scaling:

-   Single-command deployment: `docker compose up -d`
-   Automated database migrations
-   Health check monitoring
-   Backup and restore procedures
-   Log aggregation
-   Monitoring and alerting
-   Zero-downtime updates and rollback
-   Service replication, load balancing, DB clustering, cache distribution, storage expansion

### Logging, Caching, and Authentication

-   **Logging**: All logs via `loguru`, structured, context-bound, stdout for containers
-   **Caching**: Cashews only, short TTLs, logical key prefixes, use decorators, invalidate on data change
-   **Authentication**:
    -   Web UI: OAuth2 (password flow), session cookies, CSRF, Argon2 passwords
    -   Agent API: Bearer tokens (`csa_<agent_id>_<random>`), one per agent, auto-rotation, rate limiting
    -   Control API: API keys (`cst_<user_id>_<random>`), per-user, scopes, expiration, revocation
    -   All tokens: HTTPS only, auto-expire, revocable, audit-logged

### Testing & Validation

-   **Levels**: Unit (core logic), integration (API endpoints), end-to-end (workflows), performance
-   **QA**: Type checking, linting, doc coverage, security scanning

---

## 2. UI Style & Component Guide

### Color & Theme

-   **Base**: Catppuccin Macchiato palette (see style-guide for full table)
-   **Accent**: DarkViolet `#9400D3` (aliased as `accent` in DaisyUI)
-   **Surface/Foreground**: Use `surface0`, `crust`, `text`, `subtext0` for backgrounds/foregrounds
-   **No true black**; always ensure contrast for accessibility

### Layout & Spacing

-   **Base**: Flowbite Svelte Sidebar + Navbar shell
-   **Spacing**: `p-4` for containers, `grid-cols-6` for dashboard lists
-   **Modals**: Use SvelteKit modal patterns and DaisyUI modal components

### Typography

-   **Font**: System default, DaisyUI `font-sans`
-   **Headings**: `text-xl` (section), `text-lg` (card/modal)
-   **Body**: `text-base`, meta/help: `text-sm`

### Components

-   **Buttons**: Primary (`bg-accent text-white`), Secondary (`border-accent text-accent`)
-   **Badges**: Success (`bg-green-500`), Warning (`bg-yellow-400`), Error (`bg-red-600`), Info (`bg-blue-500`)
-   **Modals**: DaisyUI layout, always insert into SvelteKit modal root
-   **Toasts**: Persistent container in SvelteKit layout, DaisyUI toast class
-   **Tables**: DaisyUI/Flowbite Svelte table, alternating row color, icon column for state/action
-   **Tooltips/Validation**: Use DaisyUI/Flowbite Svelte, style tokens for info/error

### Behavioral Expectations

-   Use SvelteKit form actions and JSON API for fragments, SvelteKit stores for live updates
-   Modal forms submit via SvelteKit actions, return JSON API responses
-   WebSocket updates target fragment zones

### Branding & Iconography

-   **Motif**: Hexagons as overlays or decoration (inline SVG/local asset only)
-   **Icons**: Lucide outline SVGs, themed with `fill="currentColor"`, stored locally
-   **Attack type icons**: See style-guide for mapping

### Responsive & Accessibility

-   **Min width**: 768px, no horizontal scroll on core views
-   **Tables/charts**: Wrap in `overflow-x-auto`, pinned headers if feasible
-   **Sidebar**: Collapses below `lg` breakpoint
-   **No pixel units**: Use DaisyUI/Flowbite Svelte spacing utilities
-   **All modals, alerts, components**: Keyboard accessible, ARIA-compliant

---

## 3. Code Style & Structure

-   **Python Style**: `ruff format`, 4-space indent, 119-char lines, double quotes, type hints everywhere, `Annotated` for Pydantic fields, snake_case, PascalCase for models, no global mutable state, context managers, no print in prod
-   **Layered Architecture**: All business logic in `app/core/services/`, never in route handlers, service methods return validated Pydantic schemas
-   **Error Handling**: FastAPI `HTTPException`, custom exceptions in `app/core/exceptions.py`, RFC9457 for Control API, legacy schema for Agent API v1
-   **Background Tasks**: FastAPI BackgroundTasks or `asyncio.create_task`, jobs in `app/jobs/`, idempotent/restartable
-   **Type Checking**: Mypy with strict config, gradual adoption, CI integration

---

## 4. API Design & Conventions

-   **RESTful, versioned, documented, all endpoints use Pydantic models**
-   **Agent API**: v1 (must match `swagger.json`), v2 (idiomatic, breaking changes allowed)
-   **Web UI API**: `/api/v1/web/*` returns JSON API responses, SvelteKit handles rendering, full-page in SvelteKit routes, partials in SvelteKit components
-   **Schema & Validation**: All request/response models in `app/schemas/`, use `example`/`description`, Pydantic v2 idioms
-   **Error Handling**: Consistent error envelopes, never expose stack traces, log with loguru
-   **Authentication**: JWT for API, OAuth2 for web, CSRF for forms, Argon2 passwords
-   **Caching**: Cashews only, short TTLs, logical key prefixes, invalidate on data change

---

## 5. Testing & Quality Assurance

-   **Unit & Integration**: pytest, min 80% coverage, async SQLAlchemy, testcontainers, factories in `tests/factories/`, polyfactory for test data
-   **E2E**: Playwright scripts in `e2e/`, must cover all user-facing flows
-   **CI**: `just ci-check` runs all tests, lint, type check, and coverage
-   **Linter**: Ruff for Python, stylelint for CSS, YAML lint for workflows

---

## 6. Tooling & Dependency Management

-   **Python**: Use `uv` for all dependency management (`uv add/remove`), never edit `pyproject.toml` or `poetry.lock` directly
-   **MkDocs**: All docs in `docs/`, nav in `mkdocs.yml`, use includes/macros for reuse
-   **GitHub Actions**: Workflows in `.github/workflows/`, use secrets, cache, and artifact best practices

---

## 7. Security Best Practices

-   **Input Validation**: All input validated with Pydantic, never trust client data
-   **Database**: Only use SQLAlchemy ORM, never raw SQL, SSL for prod DB
-   **Web**: CSRF tokens for all state-changing requests, strict CORS, secure cookies, CSP headers
-   **General**: No secrets in code, use env vars, audit logs for auth/admin events

---

## 8. Frontend & UX Guidelines

-   **SvelteKit**: Use for all dynamic updates, minimal JS, prefer Svelte stores for interactivity
-   **Flowbite Svelte & DaisyUI**: Use for UI components and layout, no custom CSS unless needed
-   **Svelte**: Components in `src/lib/`, use slots, props, and context, escape all user data
-   **Accessibility**: All modals, alerts, and components must be keyboard accessible and ARIA-compliant
-   **Dashboard**: Campaigns in cards, attacks expandable, live status with SvelteKit polling

---

## 9. Git & Commit Standards

-   **Commits**: Conventional Commits: `type(scope): description`, imperative mood, no periods, use `!` for breaking changes
-   **Branching**: Feature branches, short-lived, rebase/merge often, PRs for all changes
-   **.gitignore**: Exclude build artifacts, secrets, and temp files
-   **No secrets in repo**: Use env vars and secret managers

---

## 10. Protected Zones

-   **Never auto-edit**: `alembic/`, `.cursor/`, `.github/`, `swagger.json`
-   **Markdown/docs**: Maintain by hand and keep updated when major changes are made

---

For full details and examples, see the `.cursor/rules/` directory and referenced `.mdc` files.
