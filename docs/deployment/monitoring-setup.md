# Production Monitoring Setup

## Overview

CipherSwarm includes an optional Prometheus + Grafana monitoring stack built into `docker-compose-production.yml` using Docker Compose profiles. Enable it with `--profile monitoring` — no separate compose file needed. All images are pinned for air-gapped deployment.

## Architecture

```text
┌─────────────┐     scrape /metrics      ┌──────────────┐
│  Prometheus  │◄────────────────────────│  web (Puma)   │
│  :9090       │                          └──────────────┘
│              │◄────────────────────────┌──────────────┐
│              │     scrape /metrics      │  sidekiq ×4  │
│              │                          └──────────────┘
│              │◄────────────────────────┌──────────────┐
│              │     scrape :9121         │redis-exporter│──► redis-db
│              │                          └──────────────┘
│              │◄────────────────────────┌──────────────┐
│              │     scrape :8080/metrics │     tusd     │
└──────┬───────┘                          └──────────────┘
       │ query
┌──────▼───────┐
│   Grafana    │
│   :3001      │
└──────────────┘
```

## Quick Start

### 1. Pre-pull images (on an Internet-connected machine)

```bash
docker pull prom/prometheus:v3.4.1
docker pull grafana/grafana-oss:11.6.0
docker pull oliver006/redis_exporter:v1.67.0
```

Transfer images to the air-gapped host via `docker save` / `docker load`:

```bash
# On Internet machine
docker save prom/prometheus:v3.4.1 grafana/grafana-oss:11.6.0 oliver006/redis_exporter:v1.67.0 \
  | gzip > monitoring-images.tar.gz

# On air-gapped host
docker load < monitoring-images.tar.gz
```

### 2. Configure environment

Add to your `.env`:

```bash
METRICS_ENABLED=true
GRAFANA_PASSWORD=<generated-random-password>
```

Generate and append a secure password to `.env`:

```bash
printf 'GRAFANA_PASSWORD=%s\n' "$(openssl rand -base64 16)" >> .env
```

### 3. Start with monitoring

```bash
docker compose -f docker-compose-production.yml --profile monitoring up -d
```

To run **without** monitoring (default), omit `--profile monitoring`:

```bash
docker compose -f docker-compose-production.yml up -d
```

### 4. Access Grafana

Open `http://<host>:<GRAFANA_PORT>` (default: 3001, configurable via `GRAFANA_PORT` env var) and log in with:

- **Username**: `admin`
- **Password**: the `GRAFANA_PASSWORD` you set

The "CipherSwarm Overview" dashboard is pre-provisioned.

## What's Monitored

| Category   | Metrics                                                             | Source               |
| ---------- | ------------------------------------------------------------------- | -------------------- |
| Sidekiq    | Queue depth, latency, dead set, processed/failed rate, worker count | yabeda-sidekiq       |
| PostgreSQL | Connection pool size/busy/idle/dead/waiting                         | yabeda custom gauges |
| Redis      | Memory usage, connected clients, hit rate                           | redis_exporter       |
| Rails      | Request rate, p95 latency, 5xx error rate                           | yabeda-rails         |
| tusd       | Upload metrics                                                      | tusd built-in        |

## Alerts

Alerts are evaluated by Prometheus and visible in Grafana's alerting UI. No external notification channel is needed — operators check the dashboard.

| Alert                      | Fires When                 | Severity |
| -------------------------- | -------------------------- | -------- |
| SidekiqDeadSetNonEmpty     | Dead jobs > 0 for 5m       | warning  |
| SidekiqQueueLatencyHigh    | Queue latency > 30s for 5m | warning  |
| SidekiqQueueDepthHigh      | Queue size > 1000 for 10m  | warning  |
| PGConnectionPoolExhaustion | Pool > 80% utilized for 2m | critical |
| PGConnectionPoolWaiting    | Threads waiting > 0 for 1m | critical |
| RedisMemoryHigh            | Memory > 80% of max for 5m | warning  |
| RedisDown                  | Redis unreachable for 1m   | critical |
| HighErrorRate              | 5xx rate > 5% for 5m       | warning  |

## Customization

### Adjust scrape interval

Edit `docker/monitoring/prometheus.yml`:

```yaml
global:
  scrape_interval: 30s  # default is 15s
```

### Add alert thresholds

Edit `docker/monitoring/alerts.yml` and reload Prometheus:

```bash
curl -X POST http://localhost:9090/-/reload
```

### Custom Grafana dashboards

Place JSON files in `docker/monitoring/grafana/provisioning/dashboards/`. They are auto-loaded on Grafana startup.

## Stopping Monitoring

To stop only the monitoring services while keeping the app running:

```bash
docker compose -f docker-compose-production.yml --profile monitoring stop prometheus grafana redis-exporter
```

Data is retained in `prometheus_data` and `grafana_data` volumes.
