# Style and Conventions

- Ruby: Target 3.2+, frozen string literals; 2-space indent; 120-char line length. Methods alphabetical (except init/CRUD). Max 4 params per method.
- Tests: RSpec with max ~20 lines per example, ≤5 expectations. Use FactoryBot, Page Object Pattern for system tests. Structured logging tests per docs/development/logging-guide.md.
- Rails structure: Business logic in models (no `app/services`). ViewComponent for reusable UI (`app/components`). Background jobs in app/jobs. Custom validations in `app/validators`. Routes split via `config/routes/*.rb` with draw.
- State machines via state_machines-activerecord for Agent/Attack/Task.
- Real-time via Turbo/Stimulus; keep controllers thin; use model callbacks broadcast_refreshes.
- Logging: Structured with [LogType] prefixes, include context, avoid sensitive data.
- Migrations: ALWAYS via Rails generators (bin/rails generate migration / just db-migration); never hand-write.
- JS: Stimulus controllers, Vitest for tests. Assets built via esbuild? (bin/dev via Procfile.dev). Use Hotwire conventions.
- Code quality: RuboCop Rails Omakase (.rubocop.yml). Prefer pagy for pagination. Soft deletes via paranoia. Auditing via audited. ar_lazy_preload for N+1.
- Naming: Conventional Rails naming; multi-tenancy via Projects; roles per ProjectUser.
