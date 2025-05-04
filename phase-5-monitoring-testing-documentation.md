# Phase 5: Monitoring, Testing, Documentation & Seeding

This phase covers everything needed to ensure CipherSwarm is observable, testable, well-documented, and ready to run in an airgapped environment from day one.

---

## 📊 System Monitoring

### Metrics Collection

-   [ ] Integrate Prometheus-compatible metrics
-   [ ] Use `prometheus_client` with FastAPI middleware
-   [ ] Expose `/metrics` endpoint
-   [ ] Record:
    -   Active agents
    -   Tasks by state
    -   Agent hash rate (average, peak)
    -   Failed tasks per hour
    -   API request latency/duration

### Alerting System

-   [ ] Prometheus alert rules (e.g., missed heartbeat > 60s)
-   [ ] Alert log table in DB
-   [ ] Optional: webhook to Slack/email (stub or queue)
-   [ ] Alert escalation config:
    -   Threshold, severity
    -   Notify admin
    -   Record response/ack

---

## 🧑‍💼 Management Interface

### Fleet Management

-   [ ] Agent overview table
    -   Filter by state, hashcat version, OS
    -   Pagination + sorting
-   [ ] Manual task control
    -   Cancel, requeue, force complete
-   [ ] Resource dashboard
    -   Upload new resource
    -   See usage count, last access, cached agent list
-   [ ] Health checks
    -   `last_seen_at` freshness
    -   Queue backlog for stuck agents

### Statistics Dashboard

-   [ ] Real-time stats (Redis or memory cache)
-   [ ] Time-series stats (PostgreSQL or Prometheus)
-   [ ] UI Features:
    -   Mini charts for task throughput
    -   Hashes cracked per day
    -   Agent uptime percentages
    -   Top-performing agents
    -   Recent errors

---

## 🧪 Testing Strategy

### Unit Tests

-   [ ] Use `pytest` and `pytest-asyncio`
-   [ ] Use `polyfactory` for seeding fixtures
-   [ ] Model/unit tests:
    -   Database schema logic
    -   Services/utilities
    -   Validators/enums

### API Tests

-   [ ] Endpoint validation
-   [ ] Auth checks
-   [ ] Rate limiting
-   [ ] Response formatting and schema validation

### Integration Tests

-   [ ] DB+Redis tests
-   [ ] Simulate full agent → task → result flow
-   [ ] Presigned URL integration

### System Tests

-   [ ] E2E flows (multi-agent, real cracking simulation)
-   [ ] Performance/load (simulate 20+ agents)
-   [ ] Recovery scenarios (dropped tasks, bad agents)

---

## 📚 Documentation

### API Documentation

-   [ ] OpenAPI auto-generated from FastAPI
-   [ ] Cover:
    -   Agent API
    -   Web UI API
    -   TUI CLI API
    -   Authentication examples
    -   Error reference model

### Implementation Docs

-   [ ] MkDocs site generation
-   [ ] Guides:
    -   Setup
    -   Config
    -   Deployment (airgapped!)
    -   Security hardening
    -   Troubleshooting

### Developer Docs

-   [ ] Architecture diagram
-   [ ] Component mapping
-   [ ] Data flow (agent → task → result)
-   [ ] Scaling strategy
-   [ ] Dev contribution guide

---

## 🧬 Initial Data Seeding

### Default Users

-   [ ] `admin@example.com` / role: `admin`
-   [ ] `nobody@example.com` / role: `user`

### Default Project

-   [ ] "Default Project" created at startup
-   [ ] Linked to admin user

### Operating Systems

-   [ ] Windows (hashcat.exe)
-   [ ] Linux (hashcat.bin)
-   [ ] Darwin (hashcat.bin)

### Hash Types

-   [ ] Load from static JSON
-   [ ] Examples:
    -   MD5 (mode 0)
    -   SHA1 (mode 100)
    -   NTLM (mode 1000)
    -   bcrypt (mode 3200)
    -   -   others (common top 20)

---

## 🧠 Notes for Cursor

-   Testing coverage target: 80% minimum, tracked via CI
-   All metrics must support async context to avoid blocking
-   HTMX components must be modular and independently refreshable
-   Seed script should be idempotent and safe to run multiple times
-   Airgapped: do not depend on external NPM/CDN, pull all deps locally
