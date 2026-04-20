# Agent Context

This file provides AI coding assistants with project context. All substantive documentation lives in the files linked below — read them, not this file, for implementation details.

## Project Documentation

| Document                                                                       | Contents                                                                                                                |
| ------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| [ARCHITECTURE.md](ARCHITECTURE.md)                                             | System design, deployment constraints, domain model, auth, state machines, services, storage, UI patterns, dependencies |
| [CONTRIBUTING.md](CONTRIBUTING.md)                                             | Code standards, Ruby style, testing conventions, PR process, merge queue                                                |
| [GOTCHAS.md](GOTCHAS.md)                                                       | Edge cases and hard-won lessons by domain. **Read the relevant section before working in that area.**                   |
| [docs/testing/testing-strategy.md](docs/testing/testing-strategy.md)           | Test layers, conventions, undercover, CI scope                                                                          |
| [docs/deployment/docker-development.md](docs/deployment/docker-development.md) | Docker dev setup, commands, tmpfs, env files                                                                            |
| [docs/development/developer-guide.md](docs/development/developer-guide.md)     | Detailed development commands, environment setup                                                                        |
| [docs/development/logging-guide.md](docs/development/logging-guide.md)         | Structured logging patterns                                                                                             |

## Key Constraints

- **Air-gapped production** — no Internet, no CDN, no external APIs. All deps vendored into Docker images.
- **100 GB+ attack files** — uploads via tusd (resumable), not Active Storage direct upload.
- **10+ concurrent agents** — API and job queues must handle sustained concurrent load.
- **Docker Compose only** — never introduce non-Docker deployment dependencies.

Decision filter: "Will this work on an isolated LAN with no Internet, 10+ agents, and 100 GB files?"

## Agent-Specific Notes

- Always use `just` recipes instead of raw `bundle exec` commands
- Always use Rails generators for migrations — never create migration files manually
- Service objects and concerns require a REASONING block (see CONTRIBUTING.md)
- Run `just ci-check` as final verification before claiming work is complete
- `docs/plans/` is gitignored — working implementation documents, stay local only
- `docs/solutions/` is committed — searchable knowledge base of documented solutions organized by category (e.g. `best-practices/`, `runtime-errors/`, `database-issues/`) with YAML frontmatter (`module`, `tags`, `problem_type`). Relevant when implementing or debugging in documented areas.
- `todos/` is committed — triaged follow-up backlog as `todos/NNN-<status>-<priority>-<slug>.md` (status: `pending` / `ready` / `complete`); run `/todo-triage` → `/todo-resolve` to work them

### Documentation Indexes

When adding new files:

- `docs/user-guide/` → update both `docs/user-guide/README.md` and `docs/README.md`
- `docs/deployment/` → update `docs/README.md`

### Soft-delete

Campaign and Attack use `SoftDeletable` concern (`app/models/concerns/soft_deletable.rb`), which wraps the `discard` gem. `destroy` soft-deletes (sets `deleted_at`), `default_scope -> { kept }` hides discarded rows. Reach for `.unscoped` or `.discarded` to see soft-deleted records. See `docs/solutions/best-practices/paranoia-to-discard-migration.md` for gotchas when extending this pattern.

### For planning agents

When planning new features or architectural changes, use the `layered-rails` skill for analysis:

- `/layers:gradual` — plan incremental adoption of layered patterns
- `/layers:analyze` — full codebase architecture analysis
- `/layers:review` — review code from a layered architecture perspective
- `/layers:spec-test` — apply the specification test to evaluate layer placement

## Agent Rules <!-- tessl-managed -->

@.tessl/RULES.md follow the [instructions](.tessl/RULES.md)
