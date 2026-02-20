# Production Load Balancing

## Introduction

When many cracking agents are active simultaneously, a single CipherSwarm web instance can become a bottleneck. Each agent sends periodic status updates, crack submissions, and task requests — all of which compete for the same Puma thread pool. This guide describes how to horizontally scale the web tier using nginx as a reverse proxy load balancer in front of multiple Thruster/Puma replicas.

## Architecture Overview

```
                         ┌──────────────────┐
    Cracking Agents ────>│  Nginx (port 80)  │
                         │  Load Balancer    │
                         └────────┬─────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
     ┌────────▼──────┐  ┌────────▼──────┐  ┌────────▼──────┐
     │  Web Replica 1 │  │  Web Replica 2 │  │  Web Replica N │
     │  Thruster/Puma │  │  Thruster/Puma │  │  Thruster/Puma │
     └───────┬────────┘  └───────┬────────┘  └───────┬────────┘
             │                   │                   │
             └───────────────────┼───────────────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
              ┌─────▼───┐ ┌─────▼───┐ ┌──────▼─────┐
              │PostgreSQL│ │  Redis  │ │  Sidekiq   │
              └─────────┘ └─────────┘ └────────────┘
```

**Component roles:**

- **Nginx** — Accepts all incoming HTTP traffic on port 80 and distributes requests across web replicas using the `least_conn` algorithm. Uses Docker's embedded DNS (`127.0.0.11`) to discover replicas automatically. Includes a dedicated `/cable` location for Action Cable WebSocket connections (Turbo Streams).
- **Web replicas (Thruster/Puma)** — Each replica is an independent container running the full Rails stack. Thruster handles HTTP/2 and asset serving per instance. Puma serves Rails requests with its own thread pool.
- **Backend services** — PostgreSQL, Redis, and Sidekiq are shared by all replicas. Rails cookie-based sessions are stateless, so no sticky sessions are required.

## Scaling Guidelines

### The n+1 Formula

Set the number of web replicas to **n + 1**, where **n** is the number of fully active cracking nodes. This is a conservative upper bound assuming worst-case scenarios where all agents submit status updates, crack results, and task requests simultaneously:

| Active Nodes | Recommended Replicas | Rationale             |
| :----------: | :------------------: | --------------------- |
|      4       |          5           | Small deployment      |
|      8       |          9           | Default configuration |
|      16      |          17          | Medium deployment     |
|      32      |          33          | Large deployment      |

The **+1 buffer** ensures that even if one replica is temporarily unhealthy or handling a slow request, the remaining replicas can absorb the load without queuing.

For typical deployments with 30-second heartbeat intervals, fewer replicas may suffice. Monitor nginx access logs (check `upstream_response_time`) and Puma queue depth to right-size your deployment.

### Resource Considerations

Each web replica is constrained to:

- **CPU**: 1 core (limit), 0.5 core (reservation)
- **Memory**: 512 MB (limit), 256 MB (reservation)

PostgreSQL and Sidekiq have higher resource limits (2 GB and 1 GB respectively) to handle connection pooling from multiple web replicas and background job processing.

Plan your host resources accordingly. For example, 9 web replicas require at minimum 4.5 CPU cores and 2.25 GB RAM reserved, with burst capacity up to 9 cores and 4.5 GB.

## Configuration

### Nginx (`docker/nginx/nginx.conf`)

Key settings and their purpose:

| Setting                           | Value           | Purpose                                                               |
| --------------------------------- | --------------- | --------------------------------------------------------------------- |
| `resolver 127.0.0.11`             | Docker DNS      | Discovers all web replica IPs dynamically                             |
| `zone web_backend_zone 64k`       | Shared memory   | Required for the `resolve` parameter on upstream servers              |
| `least_conn`                      | Algorithm       | Sends new requests to the replica with the fewest active connections  |
| `resolve`                         | DNS re-query    | Re-resolves DNS so new/removed replicas are picked up (nginx 1.27.3+) |
| `max_fails=3`                     | Passive health  | Marks a replica as down after 3 consecutive failures                  |
| `fail_timeout=30s`                | Recovery window | Waits 30 s before retrying a failed replica                           |
| `keepalive 32`                    | Connection pool | Reuses TCP connections to backends for efficiency                     |
| `proxy_read_timeout 300s`         | Long reads      | Allows slow API responses (e.g., large hash list downloads)           |
| `proxy_next_upstream`             | Retry policy    | Retries GET/HEAD on error, timeout, 502, 503, 504                     |
| `proxy_next_upstream_timeout 30s` | Retry budget    | Bounds total retry duration to prevent cascading delays               |
| `client_max_body_size 100M`       | Upload limit    | Accommodates large hash list and word list uploads                    |
| `/cable` location                 | WebSocket       | Upgrades connections for Action Cable (Turbo Streams)                 |

**Nginx version requirement:** The `resolve` parameter in upstream blocks requires nginx >= 1.27.3 (open-sourced from nginx Plus). The default `nginx:alpine` image (currently 1.29.x) supports this. Do not pin to an older version.

### Adjusting Timeouts

If agents experience timeouts during large file uploads or downloads, increase `proxy_read_timeout` and `proxy_send_timeout` in the nginx configuration. The default 300 s read timeout is generous but may need to be raised for very large payloads.

## Deployment Instructions

### Prerequisites

- Docker Engine 20.10+
- Docker Compose V2
- Required environment variables:
  - `RAILS_MASTER_KEY` — Rails credentials encryption key
  - `POSTGRES_PASSWORD` — PostgreSQL root password
  - `MINIO_PUBLIC_IP` — Public IP for MinIO (if using MinIO storage)

### Step-by-Step Deployment

1. **Set environment variables:**

   ```bash
   export RAILS_MASTER_KEY=your_master_key
   export POSTGRES_PASSWORD=your_secure_password
   ```

2. **Adjust the replica count** (optional — edit `docker-compose-production.yml`):

   ```yaml
   web:
     deploy:
       replicas: 9  # n+1 where n = active cracking nodes
   ```

   Or pass it at the command line (see step 3).

3. **Deploy the stack:**

   ```bash
   docker compose -f docker-compose-production.yml up -d

   # Or with a specific replica count:
   docker compose -f docker-compose-production.yml up -d --scale web=9
   ```

4. **Verify all replicas are healthy:**

   ```bash
   docker compose -f docker-compose-production.yml ps
   ```

   All web replicas and the nginx service should show `healthy` status. Note that web replicas take 10-45 seconds to boot Rails, and nginx waits for at least one healthy web replica before starting.

5. **Test load distribution** (optional):

   ```bash
   # Send several requests and observe different upstream addresses in nginx logs
   for i in $(seq 1 10); do
     curl -s -o /dev/null -w "%{http_code}\n" http://localhost/up
   done
   ```

### Scaling Without Downtime

Scale web replicas up or down at any time without restarting other services:

```bash
# Scale to 17 replicas (for 16 active nodes)
docker compose -f docker-compose-production.yml up -d --scale web=17

# Scale down to 5 replicas
docker compose -f docker-compose-production.yml up -d --scale web=5
```

Or use the justfile shortcut:

```bash
just docker-prod-scale 17
```

Nginx's DNS re-resolution (every 10 s) automatically picks up added or removed replicas.

## Monitoring and Troubleshooting

### Checking Service Health

```bash
# Overview of all services
just docker-prod-status

# Or directly
docker compose -f docker-compose-production.yml ps
```

### Viewing Logs

```bash
# Nginx access/error logs
just docker-prod-logs-nginx

# Web replica logs (all replicas interleaved)
just docker-prod-logs-web

# Specific replica logs
docker compose -f docker-compose-production.yml logs web --index 1
```

The nginx access log includes upstream context (`upstream=`, `upstream_status=`, `upstream_response_time=`, `request_time=`) to help diagnose load distribution and slow backends.

### Common Issues

| Symptom                        | Likely Cause                  | Solution                                                                       |
| ------------------------------ | ----------------------------- | ------------------------------------------------------------------------------ |
| Replicas fail to start         | Insufficient host resources   | Reduce replica count or increase host capacity                                 |
| Uneven load distribution       | DNS cache stale               | Restart nginx: `docker compose -f docker-compose-production.yml restart nginx` |
| Connection timeouts on uploads | `proxy_read_timeout` too low  | Increase timeout in `docker/nginx/nginx.conf`                                  |
| 502 Bad Gateway                | All replicas down or starting | Wait for health checks to pass; check web replica logs                         |
| Database connection errors     | Too many connections          | Tune `pool` size in `config/database.yml` or add PgBouncer                     |
| OOM kills (exit code 137)      | Memory limit too low          | Check `docker inspect --format='{{.State.OOMKilled}}'`; increase service limit |
| WebSocket disconnects          | Missing `/cable` location     | Verify `docker/nginx/nginx.conf` has the `/cable` WebSocket block              |

### Performance Monitoring

- Watch nginx access logs for slow responses (`upstream_response_time` > 1 s)
- Monitor PostgreSQL connection count: `SELECT count(*) FROM pg_stat_activity;`
- Monitor Redis memory usage: `redis-cli INFO memory`
- Track Sidekiq queue depth via the Sidekiq Web UI at `/sidekiq`

## Security Considerations

### SSL/TLS Termination

The current configuration serves plain HTTP on port 80. The `DISABLE_SSL` environment variable is set to `true` by default in `docker-compose-production.yml`, which disables Rails `force_ssl` and `assume_ssl` redirects.

For deployments exposed to untrusted networks:

1. **Recommended**: Place an external TLS-terminating reverse proxy (e.g., Caddy, Traefik, or a cloud load balancer) in front of the nginx service. Then remove `DISABLE_SSL` (or set it to empty) so Rails enforces HTTPS.
2. **Self-signed certificates** (typical for lab environments): Add TLS certificates to the nginx configuration directly by mounting certs and updating the server block to listen on 443 with `ssl_certificate` and `ssl_certificate_key`. Then remove `DISABLE_SSL`.
3. **Isolated lab environments**: The default configuration (plain HTTP with `DISABLE_SSL=true`) is appropriate when the deployment is not exposed to untrusted networks.

### Header Forwarding

Nginx forwards `X-Real-IP`, `X-Forwarded-For`, and `X-Forwarded-Proto` headers so Rails can correctly identify client IPs and protocol. Ensure any upstream proxy also preserves these headers.

### Rate Limiting

For deployments exposed to the public internet, consider adding nginx rate limiting:

```nginx
# Example: limit API endpoints to 10 requests/second per IP
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

location /api/ {
    limit_req zone=api burst=20 nodelay;
    proxy_pass http://web_backend;
    # ... other proxy settings
}
```

## Maintenance

### Rolling Updates

To update the web application image without downtime:

```bash
# Pull the latest image
docker compose -f docker-compose-production.yml pull web

# Recreate web replicas (nginx continues serving via remaining replicas)
docker compose -f docker-compose-production.yml up -d --no-deps web
```

Nginx's passive health checks automatically route traffic away from replicas that are restarting.

### Backup Considerations

- PostgreSQL data lives in the `postgres` volume — back up with `pg_dump` or volume snapshots
- Redis data lives in the `redis` volume — back up with `redis-cli BGSAVE`
- Application storage lives in the `storage` volume — back up with your preferred method

### Scaling Automation

For dynamic scaling based on agent count, you could script the replica adjustment. Note that this requires a custom API endpoint that does not yet exist:

```bash
#!/usr/bin/env bash
# Hypothetical example — requires implementing an /api/v1/agents/active_count endpoint.
ACTIVE_AGENTS=$(curl -s http://localhost/api/v1/agents/active_count)
REPLICAS=$((ACTIVE_AGENTS + 1))
docker compose -f docker-compose-production.yml up -d --scale web=$REPLICAS
```

## References

- [Nginx Upstream Module](https://nginx.org/en/docs/http/ngx_http_upstream_module.html)
- [Docker Compose Scaling](https://docs.docker.com/compose/how-tos/scaling/)
- [CipherSwarm User Guide](../user-guide/README.md)
- [CipherSwarm Air-Gapped Deployment](../user-guide/air-gapped-deployment.md)
