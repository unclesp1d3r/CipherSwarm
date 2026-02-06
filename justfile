# CipherSwarm Task Runner
# https://github.com/casey/just

set dotenv-load := true

# Use mise to manage all dev tools (ruby, bun, pre-commit, etc.)
# See .mise.toml for tool versions
mise_exec := "mise exec --"

# Default recipe (list all available commands)
default:
    @just --list

# === Development Setup ===

# Install dependencies
install:
    mise install
    {{mise_exec}} bun install
    {{mise_exec}} gem install bundler -v '~> 2.7'
    {{mise_exec}} bin/bundle install

# Setup project (install deps, prepare database)
setup: install
    {{mise_exec}} bin/setup --skip-server

# Start full development server (Rails + assets + Sidekiq)
dev:
    bin/dev

# Start Rails server only
server:
    {{mise_exec}} bin/rails server

# Start Rails console
console:
    {{mise_exec}} bin/rails console

# Start Sidekiq worker
sidekiq:
    {{mise_exec}} bundle exec sidekiq

# === Code Quality ===

# Run pre-commit hooks
pre-commit:
    {{mise_exec}} pre-commit run --all-files

# Run all linters and formatters (pre-commit equivalent)
check: pre-commit security
    @echo "✓ All checks passed"

# Auto-format all code (RuboCop, ERB)
format:
    {{mise_exec}} bundle exec rubocop -A
    {{mise_exec}} bundle exec erb_lint --lint-all --autocorrect
    @echo "✓ Code formatted"

# Run RuboCop linting only
lint:
    {{mise_exec}} bundle exec rubocop

# Run Brakeman security scanner
security:
    {{mise_exec}} bundle exec brakeman -q --no-pager

# Run all quality checks (lint + security + formatting)
quality: lint security format

# === Testing ===

# Run JavaScript tests
test-js:
    {{mise_exec}} bun test:js

# Run all tests (JS + RSpec with coverage)
test-all: test-js
    COVERAGE=true {{mise_exec}} bundle exec rspec

# Run RSpec tests with coverage
test:
    COVERAGE=true {{mise_exec}} bundle exec rspec

# Run specific test file
test-file FILE:
    {{mise_exec}} bundle exec rspec {{FILE}}

# Run system tests with visible browser
test-system:
    {{mise_exec}} bundle exec rspec spec/system

# Run tests in parallel
test-parallel:
    {{mise_exec}} bundle exec rspec --parallel

# Run API integration tests
test-api:
    {{mise_exec}} bundle exec rspec spec/requests

# Check test coverage for changed code
undercover:
    {{mise_exec}} bundle exec undercover

# Check test coverage against a specific branch
undercover-compare ref="origin/main":
    {{mise_exec}} bundle exec undercover --compare {{ref}}

# === Database Management ===

# Run pending migrations
db-migrate:
    {{mise_exec}} bin/rails db:migrate

# Rollback last migration
db-rollback:
    {{mise_exec}} bin/rails db:rollback

# Reset database (drop, create, migrate, seed)
db-reset:
    {{mise_exec}} bin/rails db:reset

# Seed database
db-seed:
    {{mise_exec}} bin/rails db:seed

# Create new migration
db-migration NAME:
    {{mise_exec}} bin/rails generate migration {{NAME}}

# Reset test database
db-test-reset:
    RAILS_ENV=test {{mise_exec}} bin/rails db:reset

# === Docker Operations ===

# Build and start development environment
docker-up:
    docker compose -p csdev up

# Build and start in watch mode (auto-reload)
docker-dev-watch:
    docker compose -p csdev up --watch

# Build and start production environment
docker-prod-up:
    docker compose -f docker-compose-production.yml up

# Stop and clean up development environment
docker-down:
    docker compose -p csdev down

# View container logs
docker-logs:
    docker compose -p csdev logs -f

# Rebuild all containers
docker-rebuild:
    docker compose -p csdev build --no-cache

# Shell into Rails container
docker-shell:
    docker compose -p csdev exec web bash

# === Asset Pipeline ===

# Build all assets (CSS + JS)
assets-build: css-build js-build

# Watch assets for changes
assets-watch:
    #!/usr/bin/env bash
    mise exec -- bun run watch:css &
    mise exec -- bun run build --watch &
    wait

# Build CSS only
css-build:
    {{mise_exec}} bun run build:css

# Watch CSS for changes
css-watch:
    {{mise_exec}} bun run watch:css

# Build JavaScript only
js-build:
    {{mise_exec}} bun run build

# Precompile assets for production
assets-precompile:
    RAILS_ENV=production {{mise_exec}} bin/rails assets:precompile

# === Background Jobs ===

# Monitor Sidekiq stats
sidekiq-monitor:
    {{mise_exec}} bundle exec sidekiqmon

# Clear Sidekiq queues
sidekiq-clear:
    {{mise_exec}} bin/rails runner 'Sidekiq.redis { |r| r.flushdb }'

# View Sidekiq web UI (requires sidekiq-web gem mounted in routes)
sidekiq-web:
    @echo "Open http://localhost:3000/sidekiq in your browser"
    @echo "Ensure Sidekiq::Web is mounted in routes.rb"

# === API Documentation ===

# Generate Swagger/OpenAPI documentation
docs-api:
    RAILS_ENV=test {{mise_exec}} rails rswag

# Regenerates Swagger/OpenAPI documentation with examples
docs-api-full:
    RSWAG_DRY_RUN=0 RAILS_ENV=test {{mise_exec}} rails rswag

# Serve documentation locally (placeholder - implement based on your docs setup)
docs-serve:
    @echo "Documentation serving not yet configured"
    @echo "Consider adding mkdocs or similar"

# Build documentation for deployment
docs-build:
    @echo "Documentation build not yet configured"

# Run integration tests and generate API docs
docs-generate: test-api docs-api

# === Maintenance ===

# Update all dependencies
update:
    {{mise_exec}} bundle update
    {{mise_exec}} bun update
    @echo "✓ Dependencies updated"

# Clean temporary files and caches
clean:
    {{mise_exec}} bin/rails tmp:clear
    {{mise_exec}} bin/rails log:clear
    rm -rf coverage/
    rm -rf tmp/cache/
    @echo "✓ Cleaned temporary files"

# View Rails routes
routes:
    {{mise_exec}} bin/rails routes

# Annotate models with schema info
annotate:
    {{mise_exec}} bundle exec annotate --models --routes

# Generate changelog (requires git-cliff)
changelog:
    git cliff -o CHANGELOG.md

ci-check: check test undercover docs-generate
    @echo "✓ CI checks passed"
