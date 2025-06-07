# 🧃 justfile — Orbit City Developer Tasks
set shell := ["bash", "-cu"]
set dotenv-load := true
set ignore-comments := true


# PHONY: default, help

default:
    just --summary

help:
    just --summary

# -----------------------------
# 🔧 Setup & Installation
# PHONY: install
# -----------------------------

install:
    cd {{justfile_dir()}}
    # 🚀 Set up dev env & pre-commit hooks
    uv sync
    uv run pre-commit install --hook-type commit-msg
    # 📦 Ensure commitlint deps are available
    npm install --save-dev commitlint @commitlint/config-conventional
    cargo install git-cliff --locked || @echo "Make sure git-cliff is installed manually"

# -----------------------------
# 🧹 Linting, Typing, Dep Check
# PHONY: check, format, format-check, lint
# -----------------------------

check:
    # 🚀 Full code + commit checks
    uv lock --locked
    uv run pre-commit run -a

format:
    cd {{justfile_dir()}}
    just frontend-format
    uv run ruff format .

format-check:
    uv run ruff format --check .

lint:
    cd {{justfile_dir()}}
    just format-check
    just check
    just frontend-lint

# -----------------------------
# 🧪 Testing & Coverage
# PHONY: test, coverage, clean-test
# -----------------------------

test:
    cd {{justfile_dir()}}
    PYTHONPATH=packages uv run python -m pytest --cov --cov-config=pyproject.toml --cov-report=xml

test-fast:
    uv run pytest --maxfail=1 --disable-warnings -v tests/

coverage:
    uv run coverage report

# -----------------------------
# 📦 Build & Clean
# PHONY: build, clean-build
# -----------------------------

clean:
    cd {{justfile_dir()}}
    @echo "🧹 Cleaning .pyc files, __pycache__, and .pytest_cache..."
    find . -type d -name "__pycache__" -exec rm -rf "{}" +
    find . -type f -name "*.pyc" -delete
    rm -rf .pytest_cache
    rm -rf dist build *.egg-info

build:
    uvx --from build pyproject-build --installer uv

clean-build:
    just ci-check
    just clean
    just build

# Clean up .pyc files, __pycache__, and pytest cache before testing
clean-test: clean
    @echo "✅ Cleaned. Running tests..."
    just test

release:
    # 📝 Generate CHANGELOG.md from commits
    @echo "🚀 Generating changelog with git-cliff..."
    git cliff -o CHANGELOG.md --config cliff.toml
    @echo "✅ Changelog updated! Commit and tag when ready."

release-preview:
    # 🔍 Preview changelog without writing
    git cliff --config cliff.toml

# -----------------------------
# 📚 Documentation
# PHONY: docs, docs-test, docs-export
# -----------------------------

docs:
    uv run mkdocs serve --dev-addr 0.0.0.0:9090

docs-test:
    uv run mkdocs build -s

docs-export:
    # 🧾 Export a single combined PDF via mkdocs-exporter
    uv run mkdocs build


# -----------------------------
# 🤖 CI Workflow
# PHONY: ci-check
# Note: Runs all checks and tests, including frontend.
# -----------------------------

ci-check:
    just format-check
    just test
    just check
    just frontend-check

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

# Full reset: drop, recreate, migrate
db-reset: db-drop-test db-migrate-test
	@echo "Test database reset and migrated successfully!"


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

# 🧱 Frontend Dev Server
frontend-dev:
    cd {{justfile_dir()}}/frontend && pnpm dev

# 🏗️ Build frontend (for static deploy)
frontend-build:
    cd {{justfile_dir()}}/frontend && pnpm install && pnpm build

# 🧪 Run unit + e2e frontend tests
frontend-test:
    just frontend-test-unit
    just frontend-test-e2e

# 🧪 Run only frontend unit tests
frontend-test-unit:
    cd {{justfile_dir()}}/frontend && pnpm exec vitest run

# 🧪 Run only frontend E2E tests
frontend-test-e2e:
    cd {{justfile_dir()}}/frontend && pnpm exec playwright test

# 🧼 Lint frontend code
frontend-lint:
    cd {{justfile_dir()}}/frontend && pnpx sv check && pnpm exec eslint .

frontend-format:
    cd {{justfile_dir()}}/frontend && pnpm format

frontend-check:
    just frontend-lint
    just frontend-test
    just frontend-build