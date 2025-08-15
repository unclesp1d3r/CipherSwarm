---
inclusion: always
---

# CipherSwarm Development Tooling Guide

## Package Management

This project uses [`uv`](https://github.com/astral-sh/uv) for Python dependency management.

### Commands

- **Add dependency**: `uv add PACKAGE_NAME`
- **Add dev dependency**: `uv add --dev PACKAGE_NAME`
- **Remove dependency**: `uv remove PACKAGE_NAME`
- **Sync dependencies**: `uv sync`

### Rules

- NEVER manually edit `pyproject.toml` dependency sections
- NEVER create or use `requirements.txt` files
- NEVER edit `uv.lock` manually
- Always use `uv` commands for dependency changes
- All dependency changes must pass `just ci-check`

## Task Runner

Use `just` for all development tasks. Key commands:

- `just install` - Setup development environment
- `just dev-backend` - Start backend with hot reload
- `just dev-frontend` - Start frontend development server
- `just test-backend` - Run backend tests with coverage
- `just lint` - Run all linting checks
- `just format` - Auto-format all code
- `just ci-check` - Run full CI validation locally

## Code Quality Tools

### Python

- **Formatter**: `ruff format` (line length: 119 chars)
- **Linter**: `ruff check` (comprehensive analysis)
- **Type Checker**: `mypy` (required for all public functions)
- **Security**: `bandit` for security scanning
- **Testing**: `pytest` with parallel execution

### Frontend

- **Package Manager**: `pnpm` (run from `frontend/` directory)
- **Linter**: ESLint with TypeScript support
- **Formatter**: Prettier
- **Testing**: Vitest + Playwright

## Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- `feat`: New feature (MINOR version)
- `fix`: Bug fix (PATCH version)
- `docs`: Documentation changes
- `refactor`: Code restructuring
- `test`: Test additions/corrections
- `chore`: Build/tooling changes

### CipherSwarm Scopes

- `(auth)`: Authentication/authorization
- `(api)`: API endpoints and routes
- `(models)`: Data models and schemas
- `(frontend)`: SvelteKit frontend
- `(docs)`: Documentation
- `(deps)`: Dependencies

### Examples

```
feat(auth): add OAuth2 token refresh
fix(api): handle null values in campaign response
docs: update installation instructions
chore(deps): update FastAPI to v0.104.0
```

## Development Environment

### Required Services

- PostgreSQL 16+ (database)
- Redis 7+ (caching/queues)
- MinIO (object storage)

### Docker Development

- `just docker-dev-up-watch` - Start with hot reload
- `just docker-dev-down` - Stop and cleanup
- All services configured in `docker-compose.dev.yml`

### Database Management

- `just db-reset` - Reset test database
- `alembic upgrade head` - Run migrations
- `just seed-e2e-data` - Seed test data

## AI Assistant Guidelines

When working with this codebase:

1. **Dependencies**: Always suggest `uv add` commands, never manual edits
2. **Testing**: Run `just test-backend` after backend changes
3. **Formatting**: Use `just format` before committing
4. **Validation**: Ensure `just ci-check` passes
5. **Commits**: Use conventional commit format with appropriate scopes
6. **Services**: Run from project root, not subdirectories (except frontend)
7. **Documentation**: Update relevant docs when adding features
