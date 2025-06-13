# 🧃 justfile — CipherSwarm Developer Tasks
set shell := ["bash", "-cu"]
set dotenv-load := true
set ignore-comments := true



default:
    just --summary

help:
    just --summary

# -----------------------------
# 🔧 Setup & Installation
# PHONY: install
# -----------------------------

# Install dependencies and setup pre-commit hooks
install:
    cd {{justfile_dir()}}
    # 🚀 Set up dev env & pre-commit hooks
    uv sync --dev
    uv run pre-commit install --hook-type commit-msg
    # 📦 Ensure commitlint deps are available
    pnpm install --save-dev commitlint @commitlint/config-conventional
    cargo install git-cliff --locked || @echo "Make sure git-cliff is installed manually"

# Update uv and pnpm dependencies
update-deps:
    cd {{justfile_dir()}}
    uv sync --dev -U
    pnpm update --latest
    cd {{justfile_dir()}}/frontend
    pnpm update --latest


# -----------------------------
# 🧹 Linting, Typing, Dep Check
# PHONY: check, format, format-check, lint
# -----------------------------

# Run all pre-commit checks
check:
    # 🚀 Full code + commit checks
    uv lock --locked
    uv run pre-commit run -a

# Format code using ruff and svelte check
format:
    cd {{justfile_dir()}}
    just frontend-format
    uv run ruff format .

# Check code formatting using ruff
format-check:
    uv run ruff format --check .

# Run all linting checks
lint:
    cd {{justfile_dir()}}
    just format-check
    just check
    just frontend-lint

# -----------------------------
# 🧪 Testing & Coverage
# PHONY: test, coverage, clean-test
# -----------------------------

# Run all pythontests
test:
    cd {{justfile_dir()}}
    PYTHONPATH=packages uv run python -m pytest --cov --cov-config=pyproject.toml --cov-report=xml

# Run all python tests with maxfail=1 and disable warnings
test-fast:
    uv run pytest --maxfail=1 --disable-warnings -v tests/

# Run coverage report
coverage:
    uv run coverage report

# -----------------------------
# 📦 Build & Clean
# PHONY: build, clean-build
# -----------------------------

# Clean up .pyc files, __pycache__, and pytest cache
clean:
    cd {{justfile_dir()}}
    @echo "🧹 Cleaning .pyc files, __pycache__, and .pytest_cache..."
    find . -type d -name "__pycache__" -exec rm -rf "{}" +
    find . -type f -name "*.pyc" -delete
    rm -rf .pytest_cache
    rm -rf dist build *.egg-info

# Build the backend project
build:
    uvx --from build pyproject-build --installer uv

# Clean up and build the project
clean-build:
    just ci-check
    just clean
    just build

# Clean up .pyc files, __pycache__, and pytest cache before testing
clean-test: clean
    @echo "✅ Cleaned. Running tests..."
    just test

# Generate CHANGELOG.md from commits
release:
    # 📝 Generate CHANGELOG.md from commits
    @echo "🚀 Generating changelog with git-cliff..."
    git cliff -o CHANGELOG.md --config cliff.toml
    @echo "✅ Changelog updated! Commit and tag when ready."

# Preview changelog without writing
release-preview:
    # 🔍 Preview changelog without writing
    git cliff --config cliff.toml

# -----------------------------
# 📚 Documentation
# PHONY: docs, docs-test, docs-export
# -----------------------------

# Serve documentation locally with mkdocs
docs:
    uv run mkdocs serve --dev-addr 0.0.0.0:9090

# Test documentation build
docs-test:
    uv run mkdocs build -s

# Export documentation to a single combined PDF
docs-export:
    # 🧾 Export a single combined PDF via mkdocs-exporter
    uv run mkdocs build


# -----------------------------
# 🤖 CI Workflow
# PHONY: ci-check
# Note: Runs all checks and tests, including frontend.
# -----------------------------

# Setup CI checks and dependencies for CI workflow
ci-setup:
    cd {{justfile_dir()}}
    uv sync --dev || @echo "Make sure uv is installed manually"
    uv run pre-commit install --hook-type commit-msg || @echo "Make sure pre-commit is installed manually"
    pnpm install --save-dev commitlint @commitlint/config-conventional || @echo "Make sure pnpm is installed manually"

# Run all checks and tests for the entire project
ci-check:
    cd {{justfile_dir()}}
    just format-check
    just check
    just test
    just frontend-check

# Run CI workflow locally with act
github-actions-test:
    cd {{justfile_dir()}}
    just ci-setup
    @echo "Running CI workflow"
    act push --workflows .github/workflows/CI.yml --container-architecture linux/amd64
    @echo "Running Code Quality workflow"
    act push --workflows .github/workflows/ci-check.yml --container-architecture linux/amd64

# Run all checks and tests for the backend
backend-check:
    cd {{justfile_dir()}}
    just format-check
    just check
    just test

# -----------------------------
# 🗄️ Database Tasks
# PHONY: db-drop-test, db-migrate-test, db-reset, check-schema
# Note: Requires $TEST_DATABASE_URL to be set in your environment.
# -----------------------------

# Drop the test database schema and recreate it
db-drop-test:
	@echo "Dropping test database..."
	@psql "$TEST_DATABASE_URL" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" || true

# Run Alembic migrations against the test database
db-migrate-test:
	@echo "Running Alembic migrations on test database..."
	@TEST_DATABASE_URL="$TEST_DATABASE_URL" alembic upgrade head

# Full reset: drop, recreate, migrate for the test database
db-reset: db-drop-test db-migrate-test
	@echo "Test database reset and migrated successfully!"

# Check the schema types against the database
check-schema:
    uv run python scripts/dev/check_schema_types.py

# Development: Run migrations and start the dev server
dev:
    cd {{justfile_dir()}}
    alembic upgrade head
    just frontend-build
    uvicorn app.main:app --reload

# -----------------------------
# Frontend Tasks
# -----------------------------

# Start the frontend dev server
frontend-dev:
    cd {{justfile_dir()}}/frontend && pnpm dev

# Build the frontend for static deploy
frontend-build:
    cd {{justfile_dir()}}/frontend && pnpm install && pnpm build

# Run unit + e2e frontend tests
frontend-test:
    just frontend-test-unit
    just frontend-test-e2e

# Run only frontend unit tests
frontend-test-unit:
    cd {{justfile_dir()}}/frontend && pnpm exec vitest run

# Run only frontend E2E tests
frontend-test-e2e:
    cd {{justfile_dir()}}/frontend && pnpm exec playwright test

# Lint frontend code using eslint and svelte check
frontend-lint:
    cd {{justfile_dir()}}/frontend && pnpx sv check && pnpm exec eslint .

# Format frontend code using pnpm format
frontend-format:
    cd {{justfile_dir()}}/frontend && pnpm format

# Run all frontend checks including linting, testing, and building
frontend-check:
    just frontend-lint
    just frontend-test
    just frontend-build

# Run only frontend E2E tests with UI for interactive testing
frontend-test-e2e-ui:
    cd {{justfile_dir()}}/frontend && pnpm exec playwright test --ui