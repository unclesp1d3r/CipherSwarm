# PostgreSQL Connection Pool Sizing

## Overview

CipherSwarm uses ActiveRecord's connection pool to manage PostgreSQL connections. Each Rails process (Puma worker or Sidekiq process) maintains its own pool. Under-sizing causes threads to block waiting for connections; over-sizing wastes PostgreSQL `max_connections` slots and memory.

## Formula

```
total_connections = (web_replicas × pool_per_web) + (sidekiq_replicas × pool_per_sidekiq) + headroom

pool_per_web      = RAILS_MAX_THREADS × 2     (from config/database.yml)
pool_per_sidekiq  = RAILS_MAX_THREADS × 2     (same formula, but RAILS_MAX_THREADS defaults to 10 in production)
headroom          = 5                          (migrations, console, health checks)
```

## Defaults

| Variable            | Web default | Sidekiq default |
| ------------------- | ----------- | --------------- |
| `RAILS_MAX_THREADS` | 10          | 10              |
| Pool per process    | 20          | 20              |
| Replicas            | 1           | 4               |

### Single-server (default)

```
= (1 × 20) + (4 × 20) + 5 = 105 connections
```

### 10-agent deployment (9 web replicas per scaling formula)

```
= (9 × 20) + (4 × 20) + 5 = 265 connections
```

### 20-agent deployment (21 web replicas)

```
= (21 × 20) + (4 × 20) + 5 = 505 connections
```

## PostgreSQL max_connections

Set `max_connections` in `postgresql.conf` (or via Docker env) to at least the calculated total. The default PostgreSQL value is **100**, which is insufficient for any scaled deployment.

```yaml
# docker-compose-production.yml (example override)
postgres-db:
  environment:
    POSTGRES_EXTRA_ARGS: -c max_connections=300
```

Or mount a custom `postgresql.conf`:

```yaml
volumes:
  - ./docker/postgres/postgresql.conf:/etc/postgresql/postgresql.conf:ro
command: postgres -c config_file=/etc/postgresql/postgresql.conf
```

## Monitoring

When the monitoring stack is enabled (`METRICS_ENABLED=true`), the Grafana dashboard shows real-time pool utilization:

- **Pool Utilization gauge** — busy / size ratio per pool
- **Pool Breakdown** — stacked area of busy, idle, dead, waiting
- **Waiting alert** — fires when any thread is blocked waiting for a connection

Alert thresholds (see `docker/monitoring/alerts.yml`):

| Alert                        | Condition          | Action                                           |
| ---------------------------- | ------------------ | ------------------------------------------------ |
| `PGConnectionPoolExhaustion` | busy/size > 80%    | Increase `RAILS_MAX_THREADS` or add web replicas |
| `PGConnectionPoolWaiting`    | waiting > 0 for 1m | Immediate investigation required                 |

## Tuning Tips

1. **Sidekiq concurrency vs pool size**: Sidekiq concurrency is set in `config/sidekiq.yml` (10 in production). The pool must be >= concurrency. The `× 2` multiplier in `database.yml` provides headroom for callbacks and eager-loaded associations that open additional connections.

2. **PgBouncer**: For deployments exceeding 300 connections, consider adding PgBouncer as a connection pooler between Rails and PostgreSQL. This reduces PostgreSQL memory pressure and allows more Rails processes with fewer backend connections.

3. **Reaping**: `reaping_frequency: 10` in `database.yml` reclaims dead connections every 10 seconds. Monitor the `db_pool_dead` metric — sustained dead connections indicate network issues or connection leaks.
