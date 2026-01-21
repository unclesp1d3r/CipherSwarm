# Just Task Runner

## Common Commands

### Development Setup

```bash
# Setup project (install deps, prepare database)
just setup

# Start full development server (Rails + assets + Sidekiq)
just dev

# Start Rails server only
just server

# Start Rails console
just console

# Start Sidekiq worker
just sidekiq
```

### Code Quality

```bash
# Run all linters and formatters (pre-commit equivalent)
just check

# Auto-format all code (RuboCop, Rufo, ERB)
just format

# Run RuboCop linting only
just lint

# Run Brakeman security scanner
just security

# Run all quality checks (lint + security + formatting)
just quality
```

### Testing

```bash
# Run all RSpec tests with coverage
just test

# Run all tests (CI equivalent - includes lint, security, test)
just ci-check

# Run specific test file
just test-file spec/models/agent_spec.rb

# Run system tests with visible browser
just test-system

# Run tests in parallel
just test-parallel

# Run API integration tests
just test-api
```

### Database Management

```bash
# Run pending migrations
just db-migrate

# Rollback last migration
just db-rollback

# Reset database (drop, create, migrate, seed)
just db-reset

# Seed database
just db-seed

# Create new migration
just db-migration NAME

# Reset test database
just db-test-reset
```

### Docker Operations

```bash
# Build and start development environment
just docker-up

# Build and start in watch mode (auto-reload)
just docker-dev-watch

# Build and start production environment
just docker-prod-up

# Stop and clean up development environment
just docker-down

# View container logs
just docker-logs

# Rebuild all containers
just docker-rebuild

# Shell into Rails container
just docker-shell
```

### Asset Pipeline

```bash
# Build all assets (CSS + JS)
just assets-build

# Watch assets for changes
just assets-watch

# Build CSS only
just css-build

# Watch CSS for changes
just css-watch

# Build JavaScript only
just js-build

# Precompile assets for production
just assets-precompile
```

### Background Jobs

```bash
# Start Sidekiq worker
just sidekiq

# Monitor Sidekiq stats
just sidekiq-monitor

# Clear Sidekiq queues
just sidekiq-clear

# View Sidekiq web UI
just sidekiq-web
```

### API Documentation

```bash
# Generate Swagger/OpenAPI documentation
just docs-api

# Serve documentation locally
just docs-serve

# Build documentation for deployment
just docs-build

# Run integration tests and generate API docs
just docs-generate
```

### Maintenance

```bash
# Update all dependencies
just update

# Clean temporary files and caches
just clean

# View Rails routes
just routes

# Annotate models with schema info
just annotate

# Generate changelog
just changelog
```
