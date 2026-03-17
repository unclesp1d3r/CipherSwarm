---
title: Sidekiq Docker /tmp Exhaustion and Large File Upload Pipeline
category: infrastructure-issues
date: 2026-03-16
tags: [docker, sidekiq, active-storage, nginx, tmpfs, thruster, uploads]
related_issues: [675, 746, 747]
components: [ProcessHashListJob, CountFileLinesJob, CalculateMaskComplexityJob, nginx, Dockerfile]
---

# Sidekiq Docker /tmp Exhaustion and Large File Upload Pipeline

## Problem

Sidekiq containers exhausted their overlay filesystem when processing large Active Storage blobs, causing `Errno::ENOSPC` failures in ingest jobs. Additionally, large file uploads (multi-GB word lists) silently failed with no user feedback.

## Root Cause

Three separate issues combined:

1. **`/tmp` on overlay**: Active Storage `blob.open` downloads files to `Dir.tmpdir` (`/tmp`) via `Tempfile.open(name, nil)`. In Docker, `/tmp` lives on the thin writable overlay layer. Concurrent Sidekiq threads downloading large blobs filled the overlay.

2. **Thruster 30s timeout**: The Thruster HTTP/2 proxy (between nginx and Puma) had a default `HTTP_READ_TIMEOUT` of 30 seconds. Large Active Storage direct uploads (PUT to `/rails/active_storage/disk/...`) exceeded this, returning a 502 with no client-side error.

3. **nginx buffering and limits**: `client_max_body_size 100M` blocked uploads over 100 MB. nginx buffered the entire upload body to `/var/cache/nginx/client_temp/` before proxying, filling the nginx container's overlay on large files.

## Key Discovery: /tmp vs /rails/tmp

Empirically verified via Docker bind mounts:

| Directory        | Contents                                    | Source                                       |
| ---------------- | ------------------------------------------- | -------------------------------------------- |
| `/tmp`           | Active Storage blob downloads during ingest | `blob.open` → `Tempfile.open` → `Dir.tmpdir` |
| `/rails/tmp`     | Bootsnap bytecode cache (~27 MB)            | Rails/Bootsnap framework                     |
| `/rails/storage` | Permanent Active Storage blobs              | `config/storage.yml` local disk service      |

The Dockerfile does not set `TMPDIR`, so Ruby defaults to `/tmp` on Linux.

## Solution

### 1. tmpfs Mounts (primary defense)

Both compose files mount tmpfs at `/tmp` and `/rails/tmp` on web and sidekiq services. Sizes are env-configurable via `TMPFS_TMP_SIZE` and `TMPFS_RAILS_TMP_SIZE`.

### 2. Pre-Download Space Check (early failure)

`TempStorageValidation` concern checks `Sys::Filesystem.stat(Dir.tmpdir).bytes_available` against `blob.byte_size` before downloading. Raises `InsufficientTempStorageError` with 5 retries + polynomial backoff, then discards with structured `[TempStorage]` log.

### 3. Thruster Removed

Puma serves directly on port 80 (`-b 0.0.0.0`). nginx handles HTTP/2, compression, and caching. Eliminated the redundant proxy layer and its timeout.

### 4. nginx Hardened

- `client_max_body_size 0` in `/rails/active_storage/` location only (100M default elsewhere)
- `proxy_request_buffering off` for Active Storage (streams uploads without temp file)
- `proxy_buffering off` for Active Storage downloads
- 1-hour timeouts on Active Storage location; 60s/300s for general routes

## Prevention

- **Always mount tmpfs** on any Docker service that processes Active Storage blobs
- **Size tmpfs** at minimum = largest single file, recommended = largest file × Sidekiq concurrency
- **Never add HTTP proxies** between nginx and Puma without verifying timeout defaults against expected upload sizes
- **Test with real-size files** — the 20 GB upload stall (#747) was only discovered during manual testing with actual wordlists

## Related

- `docs/deployment/docker-storage-and-tmp.md` — full deployment guide
- GOTCHAS.md § Infrastructure — Docker temp storage, nginx uploads, Active Storage stall
- #746 — Upload progress indicator (no UI feedback)
- #747 — Active Storage direct upload stalls on 20 GB+ (client-side MD5 hash)
