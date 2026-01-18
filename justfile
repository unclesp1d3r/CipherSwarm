# CipherSwarm Task Runner
# https://github.com/casey/just

set dotenv-load := true

# Default recipe (list all available commands)
default:
    @just --list

# === Development Setup ===

# Install all dependencies (bundler, yarn, etc.)
install:
    bin/bundle install
    yarn install

# Setup database and initial configuration
setup: install
    bin/rails db:setup
    @echo "✓ Setup complete"

# Start full development server (Rails + assets + Sidekiq)
dev:
    bin/dev

# Start Rails server only
server:
    bin/rails server

# Start Rails console
console:
    bin/rails console

# Start Sidekiq worker
sidekiq:
    bin/bundle exec sidekiq

# === Code Quality ===

# Run pre-commit hooks
pre-commit:
    pre-commit run --all-files

# Run all linters and formatters (pre-commit equivalent)
check: pre-commit security
    @echo "✓ All checks passed"

# Auto-format all code (RuboCop, ERB)
format:
    bin/bundle exec rubocop -A
    bin/bundle exec erb_lint --lint-all --autocorrect
    @echo "✓ Code formatted"

# Run RuboCop linting only
lint:
    bin/bundle exec rubocop

# Run Brakeman security scanner
security:
    bin/bundle exec brakeman -q --no-pager
# Run all quality checks (lint + security + formatting)
quality: lint security format

# === Testing ===

# Run JavaScript tests
test-js:
    yarn test:js

# Run all tests (JS + RSpec with coverage)
test-all: test-js
    COVERAGE=true bin/bundle exec rspec

# Run RSpec tests with coverage
test:
    COVERAGE=true bin/bundle exec rspec

# Run specific test file
test-file FILE:
    bin/bundle exec rspec {{FILE}}

# Run system tests with visible browser
test-system:
    bin/bundle exec rspec spec/system

# Run tests in parallel
test-parallel:
    bin/bundle exec rspec --parallel

# Run API integration tests
test-api:
    bin/bundle exec rspec spec/requests

# === Database Management ===

# Run pending migrations
db-migrate:
    bin/rails db:migrate

# Rollback last migration
db-rollback:
    bin/rails db:rollback

# Reset database (drop, create, migrate, seed)
db-reset:
    bin/rails db:reset

# Seed database
db-seed:
    bin/rails db:seed

# Create new migration
db-migration NAME:
    bin/rails generate migration {{NAME}}

# Reset test database
db-test-reset:
    RAILS_ENV=test bin/rails db:reset

# === Docker Operations ===

# Build and start development environment
docker-up:
    docker compose up

# Build and start in watch mode (auto-reload)
docker-dev-watch:
    docker compose up --watch

# Build and start production environment
docker-prod-up:
    docker compose -f docker-compose-production.yml up

# Stop and clean up development environment
docker-down:
    docker compose down

# View container logs
docker-logs:
    docker compose logs -f

# Rebuild all containers
docker-rebuild:
    docker compose build --no-cache

# Shell into Rails container
docker-shell:
    docker compose exec web bash

# === Asset Pipeline ===

# Build all assets (CSS + JS)
assets-build: css-build js-build

# Watch assets for changes
assets-watch:
    #!/usr/bin/env bash
    yarn watch:css &
    yarn build --watch &
    wait

# Build CSS only
css-build:
    yarn build:css

# Watch CSS for changes
css-watch:
    yarn watch:css

# Build JavaScript only
js-build:
    yarn build

# Precompile assets for production
assets-precompile:
    RAILS_ENV=production bin/rails assets:precompile

# === Background Jobs ===

# Monitor Sidekiq stats
sidekiq-monitor:
    bin/bundle exec sidekiqmon

# Clear Sidekiq queues
sidekiq-clear:
    bin/rails runner 'Sidekiq.redis { |r| r.flushdb }'

# View Sidekiq web UI (requires sidekiq-web gem mounted in routes)
sidekiq-web:
    @echo "Open http://localhost:3000/sidekiq in your browser"
    @echo "Ensure Sidekiq::Web is mounted in routes.rb"

# === API Documentation ===

# Generate Swagger/OpenAPI documentation
docs-api:
    RAILS_ENV=test bin/rails rswag

# Regenerates Swagger/OpenAPI documentation with examples
docs-api-full:
    RSWAG_DRY_RUN=0 RAILS_ENV=test bin/rails rswag

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
    bin/bundle update
    yarn upgrade
    @echo "✓ Dependencies updated"

# Clean temporary files and caches
clean:
    bin/rails tmp:clear
    bin/rails log:clear
    rm -rf coverage/
    rm -rf tmp/cache/
    @echo "✓ Cleaned temporary files"

# View Rails routes
routes:
    bin/rails routes

# Annotate models with schema info
annotate:
    bin/bundle exec annotate --models --routes

# Generate changelog (requires git-cliff)
changelog:
    git cliff -o CHANGELOG.md

ci-check: check test docs-generate
    @echo "✓ CI checks passed"
