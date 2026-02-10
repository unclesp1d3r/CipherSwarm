---
name: cipherswarm-patterns
description: Coding patterns extracted from CipherSwarm repository
version: 1.0.0
source: local-git-analysis
analyzed_commits: 200
---

# CipherSwarm Patterns

## Commit Conventions

83% of commits follow **conventional commits** format:

| Type        | Count | Usage                                |
| ----------- | ----- | ------------------------------------ |
| `feat:`     | 33    | New features                         |
| `fix:`      | 28    | Bug fixes                            |
| `docs:`     | 25    | Documentation (frequently AGENTS.md) |
| `chore:`    | 58    | Maintenance, deps, config            |
| `refactor:` | 11    | Code restructuring                   |
| `test:`     | 8     | Test-only changes                    |
| `perf:`     | 2     | Performance improvements             |

Scope notation used occasionally: `feat(campaign):`, `fix(preemption):`, `chore(deps):`

## Code Architecture

```
app/
  controllers/
    api/v1/client/    # Agent API (token auth)
    admin/            # Admin dashboard
    concerns/         # Shared controller logic
  models/
    concerns/         # Model concerns with REASONING blocks
    concerns/agent/   # Agent-specific concerns
  services/           # Service objects (6 files)
  components/         # ViewComponent (railsboot/)
  dashboards/         # Administrate dashboards
  jobs/               # Sidekiq background jobs
  validators/         # Custom validators
  views/api/v1/       # Jbuilder API templates

spec/
  models/             # Unit tests
  services/           # Service tests
  requests/           # API/request tests (also generates Swagger)
  system/             # Capybara system tests
  support/
    page_objects/     # Page Object Pattern
    shared_examples/  # Shared RSpec examples
  components/         # ViewComponent tests
  factories/          # FactoryBot factories
```

## Workflows

### Adding a Service Object

1. Create `app/services/{name}_service.rb` with REASONING block
2. Create `spec/services/{name}_service_spec.rb`
3. Inject service from controller (thin controllers)

### PR Review Cycle

Pattern observed in 10+ commits:

1. Submit PR
2. Automated review (CodeRabbit, Traycer)
3. `fix: address PR review comments for {feature}`
4. Often followed by `docs: update AGENTS.md with session learnings`

### Test Stability Fixes

Recurring pattern (3 commits):

1. Identify flaky/brittle test in CI
2. Root cause: non-deterministic ordering, external resource dependency, or Turbo Stream timing
3. Fix with deterministic tiebreakers, request specs, or DB-level assertions

### Database Changes

1. ALWAYS use Rails generators: `bin/rails generate migration`
2. Never create migration files manually (causes schema drift)
3. Include REASONING block in migration comments

## Testing Patterns

- **Framework**: RSpec + FactoryBot
- **Coverage**: `COVERAGE=true bundle exec rspec`, then undercover for changed-code coverage
- **System tests**: Page Object Pattern, Capybara + Selenium Chrome
- **API tests**: RSwag generates Swagger docs from request specs
- **CI gotchas**: External font loading hangs headless Chrome; file downloads need request specs
- **State machine tests**: `transition any => same` always succeeds; use `update_column` to test failure paths
- **Turbo Stream tests**: Don't wait for flash; use `sleep 1` + `task.reload` for DB assertions

## Key Domain Patterns

- **State machines** on Agent, Attack, Task (state_machines-activerecord)
- **Priority-based preemption**: Higher priority campaigns pause lower ones
- **Agent task assignment**: Scoped to agent's projects + hash type benchmarks
- **CanCanCan authorization**: Nested association paths for tasks (`attack: { campaign: { project_id: } }`)
- **Structured logging**: `[LogType]` prefixes with context IDs

## Environment & Tooling

- **mise** for tool versions (Ruby, Bun, Just, etc.)
- **Just** as task runner (`just test`, `just check`, `just dev`)
- **Bun** instead of npm/yarn
- **Docker Compose** for PostgreSQL (`postgres-db` service, user: root, password: password)
- **Local PostgreSQL conflicts**: Must `brew services stop postgresql@17` before using Docker PG on port 5432
- **Pre-commit hooks**: RuboCop, shellcheck, mdformat
