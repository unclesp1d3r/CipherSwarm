# CipherSwarm Task Runner
# https://github.com/casey/just

set dotenv-load := true

# Default recipe (list all available commands)
default:
    @just --list

# === Development Setup ===

# Install all dependencies (bundler, yarn, etc.)
install:
    bundle install
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
    bundle exec sidekiq

# === Code Quality ===

# Run all linters and formatters (pre-commit equivalent)
check: lint security
    @echo "✓ All checks passed"

# Auto-format all code (RuboCop, Rufo, ERB)
format:
    bundle exec rubocop -A
    bundle exec rufo .
    bundle exec erblint --lint-all --autocorrect
    @echo "✓ Code formatted"

# Run RuboCop linting only
lint:
    bundle exec rubocop

# Run Brakeman security scanner
security:
    bundle exec brakeman -q

# Run all quality checks (lint + security + formatting)
quality: lint security format

# === Testing ===

# Run all RSpec tests with coverage
test:
    COVERAGE=true bundle exec rspec

# Run all tests (CI equivalent - includes lint, security, test)

# Run specific test file
test-file FILE:
    bundle exec rspec {{FILE}}

# Run system tests with visible browser
test-system:
    bundle exec rspec spec/system

# Run tests in parallel
test-parallel:
    bundle exec rspec --parallel

# Run API integration tests
test-api:
    bundle exec rspec spec/requests

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
    bundle exec sidekiqmon

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
    bin/rails rswag:specs:swaggerize

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
    bundle update
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
    bundle exec annotate --models --routes

# Generate changelog (requires git-cliff)
changelog:
    git cliff -o CHANGELOG.md

ci-check: check test
    @echo "✓ CI checks passed"
