# Docker Development

Local development can use Docker for services (PostgreSQL, Redis) while running Rails natively, or run the full stack in containers.

## Quick Start

```bash
# Start development environment (full stack)
docker compose up --watch

# Or just the services Rails needs
docker compose up -d postgres-db redis-db
```

## Service Names

- PostgreSQL: `postgres-db` (not `db`)
- Redis: `redis-db`

## Running Tests with Docker PostgreSQL

Docker PG binds to IPv6 (`*:5432`) — use `localhost` not `127.0.0.1`:

```bash
# Stop local PostgreSQL if it conflicts
brew services stop postgresql@17

# Start Docker PostgreSQL
docker compose up -d postgres-db

# Run tests
TEST_DATABASE_URL=postgres://root:password@localhost:5432/cipher_swarm_test bundle exec rspec
```

## Production Stack

```bash
# Start production environment
docker compose -f docker-compose-production.yml up

# Scale web replicas (formula: n+1 where n = active cracking nodes)
just docker-prod-scale 9

# Status and logs
just docker-prod-status
just docker-prod-logs-nginx
just docker-prod-logs-web

# Shell into Rails container
just docker-shell
```

Nginx sits in front of horizontally-scaled web replicas. Config at `docker/nginx/nginx.conf`.

## Build Configuration

`JSBUNDLING_BUILD_COMMAND` env var overrides the JS build script used by `rails assets:precompile`. Set to `bun run build:production` in the Dockerfile for minified bundles. Do NOT run a separate `bun run build:production` before `assets:precompile` — it will be overwritten by the default non-minified build.

## Temp Storage and tmpfs

Both compose files mount `tmpfs` at `/tmp` and `/rails/tmp` on web and sidekiq services to prevent overlay filesystem exhaustion.

| Mount        | Purpose                                              | Default Size              |
| ------------ | ---------------------------------------------------- | ------------------------- |
| `/tmp`       | Active Storage `blob.open` downloads, job temp files | `1g` (dev), `512m` (prod) |
| `/rails/tmp` | Bootsnap cache (~27 MB)                              | `256m`                    |

Sizes configurable via `TMPFS_TMP_SIZE` and `TMPFS_RAILS_TMP_SIZE` env vars.

Key details:

- Active Storage `blob.open` downloads to `/tmp` (OS temp), not `/rails/tmp` — the Dockerfile does not set `TMPDIR`
- `TempStorageValidation` concern checks available `/tmp` space before downloading
- `InsufficientTempStorageError` retries 5 times with polynomial backoff, then discards with `[TempStorage]` log message
- Nginx: `client_max_body_size 0` (unlimited) + `proxy_request_buffering off` for large uploads

See `docs/deployment/docker-storage-and-tmp.md` for production sizing guidance.

## Environment Files

| File     | Purpose                            | Committed?      |
| -------- | ---------------------------------- | --------------- |
| `.env`   | Secrets (DB credentials, API keys) | No (gitignored) |
| `.envrc` | Environment isolation (direnv)     | Yes             |

`.envrc` auto-loads via direnv; automatically unsets `TEST_DATABASE_URL` from other projects.
