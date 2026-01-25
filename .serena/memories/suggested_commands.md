# Suggested Commands (macOS)

## Setup

- `just setup` (or `bun install && bin/setup --skip-server`) (or `bin/rails db:create db:migrate`)

## Run app

- `just dev` (runs Rails + assets + Sidekiq via Procfile.dev)
- `bin/dev`
- Docker dev: `docker compose up --watch`

## Tests

- All: `just test` or `COVERAGE=true bundle exec rspec`
- System: `just test-system` or `bundle exec rspec spec/system`
- Specific file: `just test-file spec/path/to/spec.rb`
- API/request: `just test-api` or `bundle exec rspec spec/requests`
- JS: `bun test:js`

## Quality

- All checks: `just check`
- RuboCop: `just lint`
- Format: `just format`
- Security: `just security`

## DB

- Migrate: `just db-migrate`
- Rollback: `just db-rollback`
- Reset: `just db-reset`
- New migration: `just db-migration AddFieldToModel` (uses generator)

## Assets

- Build: `just assets-build`
- Watch: `just assets-watch`

## Background jobs

- Sidekiq: `just sidekiq`
- Clear queues: `just sidekiq-clear`

## Docs

- API docs: `just docs-api` or `RAILS_ENV=test rails rswag`
- Generate docs: `just docs-generate`

## Misc

- Admin dashboard: /admin (browser)
- Sidekiq UI: /sidekiq (admin)
- Coverage report: `open coverage/index.html`

## Git helpers (macOS/Darwin)

- `ls`, `find . -name`, `rg PATTERN`, `git status`, `git diff`.
