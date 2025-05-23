# 🧃 justfile — Orbit City Developer Tasks
set shell := ["bash", "-cu"]

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
    uv run ruff format .

format-check:
    uv run ruff format --check .

lint:
    just format-check
    just check

# -----------------------------
# 🧪 Testing & Coverage
# PHONY: test, coverage, clean-test
# -----------------------------

test:
    PYTHONPATH=packages uv run python -m pytest --cov --cov-config=pyproject.toml --cov-report=xml

coverage:
    uv run coverage report

# -----------------------------
# 📦 Build & Clean
# PHONY: build, clean-build
# -----------------------------

clean:
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
    uv run mkdocs serve --dev-addr 0.0.0.0:9000

docs-test:
    uv run mkdocs build -s

docs-export:
    # 🧾 Export a single combined PDF via mkdocs-exporter
    uv run mkdocs build


# -----------------------------
# 🤖 CI Workflow
# PHONY: ci-check
# -----------------------------

ci-check:
    just format-check
    just test
    just check

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
    alembic upgrade head
    uvicorn app.main:app --reload

test-frontend:
    @echo "Running Playwright E2E frontend tests..."
    bash -c 'for script in e2e/test_*.py; do echo "==> $script"; python "$script" || exit 1; done'
    @echo "✅ All frontend E2E tests completed."


# Use lowercase for recipe name, and `file` is reserved so use `target` instead
insert-json-refactor-header target:
    @echo '"""' > {{target}}.tmp
    @echo '🧭 JSON API Refactor - CipherSwarm Web UI' >> {{target}}.tmp
    @echo '' >> {{target}}.tmp
    @echo 'Follow these rules for all endpoints in this file:' >> {{target}}.tmp
    @echo '1. Must return Pydantic models as JSON (no TemplateResponse or render()).' >> {{target}}.tmp
    @echo '2. Must use FastAPI parameter types: Query, Path, Body, Depends, etc.' >> {{target}}.tmp
    @echo '3. Must not parse inputs manually — let FastAPI validate and raise 422s.' >> {{target}}.tmp
    @echo '4. Must use dependency-injected context for auth/user/project state.' >> {{target}}.tmp
    @echo '5. Must not include database logic — delegate to a service layer (e.g. campaign_service).' >> {{target}}.tmp
    @echo '6. Must not contain HTMX, Jinja, or fragment-rendering logic.' >> {{target}}.tmp
    @echo '7. Must annotate live-update triggers with: # WS_TRIGGER: <event description>' >> {{target}}.tmp
    @echo '8. Must update test files to expect JSON (not HTML) and preserve test coverage.' >> {{target}}.tmp
    @echo '' >> {{target}}.tmp
    @echo '📘 See canonical task list and instructions:' >> {{target}}.tmp
    @echo '↪️  docs/v2_rewrite_implementation_plan/side_quests/web_api_json_tasks.md' >> {{target}}.tmp
    @echo '"""' >> {{target}}.tmp
    @echo '' >> {{target}}.tmp
    @cat {{target}} >> {{target}}.tmp
    @mv {{target}}.tmp {{target}}


