# CipherSwarm System Health UX Design

Last updated: 2025-10-12

---

## Table of Contents

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=2 --minlevel=1 -->

- [CipherSwarm System Health UX Design](#cipherswarm-system-health-ux-design)
  - [Table of Contents](#table-of-contents)
  - [Purpose](#purpose)
  - [Layout Overview](#layout-overview)
  - [Service Status Cards](#service-status-cards)
  - [Design Considerations](#design-considerations)
  - [Real-Time Behavior](#real-time-behavior)
  - [Access Control](#access-control)
  - [Data Collection Strategy](#data-collection-strategy)
  - [Observability Notes](#observability-notes)
  - [Implementation Notes](#implementation-notes)

<!-- mdformat-toc end -->

---

## Purpose

The System Health page serves as an operational dashboard, offering immediate insights into the status and performance of critical backend services. It aims to facilitate proactive monitoring and swift issue identification, ensuring the reliability and efficiency of CipherSwarm's infrastructure.

## Layout Overview

The page uses a **responsive grid layout**, with each service (Object Storage, Cache, Database) represented as a distinct **status card**. Each card provides real-time metrics and status indicators at a glance. The visual design follows a clean server status layout pattern, aligning with existing CipherSwarm styling.

## Service Status Cards

In addition to backend services, this page also displays the current operational state of all registered agents. Agents are considered system-level participants and should be included in the health view.

### Object Storage

- **Status Indicator**: 🟢 Healthy, 🟡 Degraded, 🔴 Unreachable (color-coded badge)

- **Metrics**:

  - Latency (API response time)
  - Errors (I/O and timeout count)
  - Storage Utilization (used vs total capacity)

- **Health Source**: Storage service health endpoint

### Cache Service

Cache service health is monitored through direct service queries. Do **not** use shell commands for metrics collection.

| Metric             | Source                  | Notes                         |
| ------------------ | ----------------------- | ----------------------------- |
| Up/Down State      | Service ping            | Fast and safe health check    |
| Latency            | Simple command timing   | e.g., GET/SET roundtrip time  |
| Memory Usage       | Service info            | Returns bytes in use          |
| Active Connections | Service info            | Useful for system health card |
| Keyspace Stats     | Service info (optional) | Admin-only detailed breakdown |

> These values are readily available without external tooling and can be updated live via real-time polling or background jobs.

- **Status Indicator**: Color-coded badge

- **Metrics**:

  - Command Latency
  - Memory Usage
  - Active Connections

- **Health Source**: Cache service info commands

### Database

Database health is monitored through pooled connections and system queries. No shell commands should be used.

| Metric               | Query or Method                 | Notes                                        |
| -------------------- | ------------------------------- | -------------------------------------------- |
| Up/Down State        | Simple `SELECT 1` with timeout  | Indicates connection availability            |
| Query Latency        | Time an example query execution | Consider averaging or sampling over interval |
| Connection Pool      | Pool inspection tools           | Or count active connections                  |
| Long-running Queries | System activity view            | Admin-only display                           |
| Replication Lag      | Replication status view         | Shown only if replication is configured      |
| Background Workers   | Background worker stats         | Admin-only, useful for diagnosing slowdowns  |

> Data should be cached briefly (5–15s) if queried frequently. Limit admin-only data to a collapsed view by default.

- **Status Indicator**: Color-coded badge

- **Metrics**:

  - Query Latency
  - Connection Pool Usage
  - Replication Lag (if applicable)

- **Health Source**: Database system views

### Agents

- **Status Indicator**: Color-coded badge (🟢 Online, 🔴 Offline)

- **Metrics**:

  - Last seen timestamp
  - Current assigned task (if any)
  - Guess rate (if available)

- **Grouping**: Display as a collapsible section or in its own row below Cache/Database services

## Design Considerations

### Empty/Error State UX

- If a service cannot be reached, show a red badge and a concise message (e.g., "Cache service unreachable — last seen 2m ago").

- Use skeleton loaders during initial load.

- If no data is available for a metric, show a subtle placeholder (e.g., “N/A” or gray indicator) with tooltip explaining why.

- Align with style-guide.md (dark mode, purple accent, etc.)

- Use standard component patterns

- Emphasize clarity and minimalism — show only relevant metrics

- Enable hover tooltips for metric definitions if space is tight

## Real-Time Behavior

### Update Strategy

- Live metrics should update every 5–10 seconds via real-time streaming from the JSON API.

- Expensive queries (like object counts or database stats) should be cached for 30–60 seconds server-side.

- Consider staggered refresh intervals or jitter to avoid burst load after page load.

- Real-time streaming updates for all metrics

- Stale data indication if no update received in 30s

- Optional retry/backoff on failure, with error banners if a system is unreachable

## Access Control

### Admin Access Enhancements

Users with administrative privileges may see additional diagnostic data on this page, including:

- **Object Storage**:

  - Bucket/container count and object totals
  - Disk I/O metrics

- **Cache Service**:

  - Keyspace breakdown (e.g., # keys by TTL)
  - Eviction stats

- **Database**:

  - Long-running queries
  - Background worker stats
  - Transaction log volume

This data is hidden for standard users to reduce clutter and limit sensitive system-level insight.

- Visible to all authenticated users
- Admins see more detailed metrics, logs, or advanced diagnostics

## Data Collection Strategy

> ⚠️ Implementation Note: All system metrics should be gathered **from in-process code** using libraries or internal APIs.
>
> Do **not** shell out to external binaries or system commands to collect data in production.

| Service            | Access Notes                                                                 |
| ------------------ | ---------------------------------------------------------------------------- |
| **Object Storage** | Use HTTP client to query health endpoints or admin API with access keys      |
| **Cache Service**  | Use service client library to query info/stats                               |
| **Database**       | Use ORM or database driver to run system queries                             |
| **Agents**         | Query internal ORM models and use performance timeseries methods for metrics |

- **Object Storage**: Built-in health endpoints or basic probes via client library
- **Cache Service**: INFO/STATS commands or metrics endpoint
- **Database**: System activity views, replication status views, etc.

## Observability Notes

CipherSwarm prioritizes lightweight, embedded observability over heavy external integration. This health dashboard reflects that intent:

- Metrics should be pulled directly from local service APIs or shallow internal probes.

- Do **not** require Prometheus, OpenTelemetry, or external collectors to render this page.

- However, hooks should be designed with extensibility in mind:

  - A shared metrics module or state management layer can abstract the source
  - If Prometheus or OpenTelemetry is adopted later, it should be easy to drop in as a provider

This keeps the UX fast, testable, and offline-compatible — aligning with CipherSwarm's goals.

### Object Storage via Client Library

The storage client library can be used for basic health checks and metadata without shelling out:

| Metric                   | Method                          | Notes                            |
| ------------------------ | ------------------------------- | -------------------------------- |
| Up/Down State            | List buckets/containers         | Fast + safe connectivity check   |
| Bucket Count             | Count buckets/containers        | Low cost                         |
| Object Count (optional)  | List and count objects          | Expensive; use caching if needed |
| Storage Usage (optional) | Sum object sizes across buckets | Also expensive; cache if shown   |

> Recommended approach: show only bucket count and service reachability by default. Larger metrics should be backgrounded or admin-only.

## Implementation Notes

- Status cards should be uniform height and width
- Use icons and badge color to reinforce state
- Consider sparkline or mini-chart if historical data is available
