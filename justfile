# 🧃 justfile — Orbit City Developer Tasks
set shell := ["bash", "-cu"]

default:
    just --summary

# -----------------------------
# 🔧 Setup & Installation
# -----------------------------

install:
    # 🚀 Set up dev env & pre-commit hooks
    uv sync
    uv run pre-commit install --hook-type commit-msg
    # 📦 Ensure commitlint deps are available
    npm install --save-dev commitlint @commitlint/config-conventional
    cargo install git-cliff --locked || echo "Make sure git-cliff is installed manually"

# -----------------------------
# 🧹 Linting, Typing, Dep Check
# -----------------------------

check:
    # 🚀 Full code + commit checks
    uv lock --locked
    uv run pre-commit run -a
    uv run mypy
    uv run deptry .

format:
    uv run ruff format .

format-check:
    uv run ruff format --check .

# -----------------------------
# 🧪 Testing & Coverage
# -----------------------------

test:
    PYTHONPATH=packages uv run python -m pytest --cov --cov-config=pyproject.toml --cov-report=xml

coverage:
    uv run coverage report

# -----------------------------
# 📦 Build & Clean
# -----------------------------

build:
    just clean-build
    uvx --from build pyproject-build --installer uv

clean-build:
    rm -rf dist build *.egg-info

# Clean up .pyc files, __pycache__, and pytest cache before testing
clean-test:
    echo "🧹 Cleaning .pyc files, __pycache__, and .pytest_cache..."
    find . -type d -name "__pycache__" -exec rm -rf {} +
    find . -type f -name "*.pyc" -delete
    rm -rf .pytest_cache
    echo "✅ Cleaned. Running tests..."
    just test

release:
    # 📝 Generate CHANGELOG.md from commits
    echo "🚀 Generating changelog with git-cliff..."
    git cliff --prepend CHANGELOG.md --config cliff.toml
    echo "✅ Changelog updated! Commit and tag when ready."

release-preview:
    # 🔍 Preview changelog without writing
    git cliff --config cliff.toml

# -----------------------------
# 📚 Documentation
# -----------------------------

docs:
    uv run mkdocs serve

docs-test:
    uv run mkdocs build -s

docs-export:
    # 🧾 Export a single combined PDF via mkdocs-exporter
    uv run mkdocs build


# -----------------------------
# 🤖 CI Workflow
# -----------------------------

ci-check:
    just format-check
    just check
    just test
