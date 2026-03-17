# Docker Storage and /tmp Management

## Problem

Sidekiq containers can exhaust their overlay filesystem when processing large Active Storage blobs (hash lists, wordlists, rule files). The failure surfaces as `Errno::ENOSPC` in jobs like `ProcessHashListJob`.

## Root Cause

Background jobs (e.g., `ProcessHashListJob`, `CountFileLinesJob`, `CalculateMaskComplexityJob`) must download attack resources — hash lists, wordlists, rule files, mask lists — from storage (local disk or S3) to a temporary location for analysis during ingest. Active Storage's `blob.open` calls Ruby's `Tempfile.open` which writes the entire file to `Dir.tmpdir`. On Linux (including Docker Alpine containers), this defaults to `/tmp`. The files are **not** retained after the job finishes; this is only needed for initial ingest and analysis.

In a Docker container, `/tmp` lives on the container's writable overlay layer — a thin, size-limited filesystem backed by the host's Docker storage driver. Under sustained load (multiple Sidekiq threads downloading and processing large files concurrently), the overlay fills up and subsequent writes fail.

This applies regardless of storage backend — even when using S3, Active Storage must download the full blob to `/tmp` before the job can read its contents.

The problem is amplified in production where:

- Sidekiq runs with concurrency 10 (up to 10 concurrent blob downloads to `/tmp` per container)
- Multiple Sidekiq replicas share the same image but each has its own overlay
- Attack resources (especially wordlists) can be hundreds of megabytes or larger

### Why /tmp and not /rails/tmp?

Active Storage's download path is: `blob.open` → `ActiveStorage::Downloader#open_tempfile` → `Tempfile.open(name, nil)`. When the `tmpdir` argument is `nil` (the default), Ruby uses `Dir.tmpdir`, which resolves to `/tmp` on Linux unless the `TMPDIR` environment variable is set. The CipherSwarm Dockerfile does not set `TMPDIR`, so all Active Storage temp files land in `/tmp`.

## Fix: tmpfs Mounts

Both `docker-compose.yml` and `docker-compose-production.yml` mount tmpfs filesystems on the Sidekiq and web services. There are **two** temp directories that need protection from overlay exhaustion:

### /tmp — Active Storage blob downloads

Active Storage's `blob.open` writes temp files to `/tmp` via Ruby's `Tempfile.open`. This is where the large attack resource downloads land during ingest jobs.

### /rails/tmp — Rails application temp directory

Rails uses `/rails/tmp` for Bootsnap bytecode cache (`tmp/cache/bootsnap/`), Puma PID files (`tmp/pids/`), and other framework temp files. While individual files are small, they accumulate over the lifetime of a container and can exhaust the overlay filesystem on long-running deployments.

### Configuration

```yaml
# Both web and sidekiq services
tmpfs:
  - /tmp:size=${TMPFS_TMP_SIZE:-512m},mode=1777
  - /rails/tmp:size=${TMPFS_RAILS_TMP_SIZE:-256m},mode=1777
```

- **`size`** — Maximum size of the tmpfs. Counts against the container's memory limit.
- **`mode=1777`** — Standard `/tmp` permissions (world-writable with sticky bit).
- **`TMPFS_TMP_SIZE`** / **`TMPFS_RAILS_TMP_SIZE`** — Environment variables that override the default sizes. Set these in `.env` or your deployment environment to tune for your workload.

The `/tmp` mount needs to be large enough for concurrent blob downloads (see sizing guidance below). The `/rails/tmp` mount is smaller since it only holds framework temp files — 256 MB is generous for typical deployments.

## Sizing Guidance

The right tmpfs size depends on your deployment scale and the size of files your campaigns process. The table below assumes typical attack files under 50 MB each. **If your largest file exceeds 50 MB, use the formula in the "Estimating tmpfs needs" section instead.**

| Deployment scale          | Sidekiq replicas | Concurrency | Container memory limit | Recommended `/tmp` tmpfs |
| ------------------------- | ---------------- | ----------- | ---------------------- | ------------------------ |
| Development / single node | 1                | 5           | (unlimited)            | 1 GB                     |
| Small production          | 1-2              | 10          | 2 GB                   | 512 MB                   |
| Medium production         | 4                | 10          | 2 GB                   | 512 MB                   |
| Large production          | 8+               | 10          | 4 GB+                  | 1-2 GB                   |

**Key constraint:** tmpfs memory is subtracted from the container's memory limit (`deploy.resources.limits.memory`). Both tmpfs mounts count against the limit: the default `/tmp` (512 MB) plus `/rails/tmp` (256 MB) consume 768 MB combined. With the default 2 GB worker memory limit, this leaves ~1.25 GB for the Ruby process (heap, stack, and gem memory). If you increase either tmpfs size, increase the memory limit proportionally to avoid OOM kills.

### Minimum size requirement

The tmpfs **must** be at least as large as your single largest attack file (word list, mask list, rule file, or hash list). Active Storage downloads the entire blob to `/tmp` before processing, so a file that exceeds the tmpfs size will always fail — regardless of concurrency or retry attempts.

In practice, the tmpfs should be **several times larger** than your largest file because Sidekiq processes multiple jobs concurrently — each downloading its own blob to `/tmp` at the same time.

### Estimating tmpfs needs

```text
minimum_tmpfs  = largest_single_file
recommended    = largest_single_file * sidekiq_concurrency
```

For example, if your largest wordlist is 200 MB and Sidekiq concurrency is 10, peak tmp usage could reach 2 GB. The absolute minimum tmpfs would be 200 MB (enough for one file), but 512 MB–2 GB is recommended to handle concurrent downloads plus Ruby's own temp files and OS overhead.

## Pre-Download Space Check

Before downloading any blob, each ingest job checks whether `/tmp` has enough available space to hold the file. This prevents jobs from starting a large download that would exhaust the tmpfs mid-transfer, leaving behind a partial temp file that wastes space until the container restarts.

The check compares `Sys::Filesystem.stat(Dir.tmpdir).bytes_available` against the blob's `byte_size`. If available space is less than or equal to the blob size, the job raises `InsufficientTempStorageError` **before** the download begins — no bytes are written to `/tmp`.

### Which jobs are protected

All three jobs that call `blob.open` include the `TempStorageValidation` concern:

- **`ProcessHashListJob`** — downloads hash lists to parse and ingest hash items
- **`CountFileLinesJob`** — downloads wordlists, rule lists, mask lists, and hash lists to count lines
- **`CalculateMaskComplexityJob`** — downloads mask lists to compute keyspace complexity

### Retry and discard behavior

**Retry:** Jobs retry 5 times with increasing delays (polynomial backoff). This handles transient space pressure — when multiple jobs are downloading concurrently, space often frees up as other jobs finish and their temp files are cleaned up.

**Discard:** After 5 failed attempts, the job is permanently discarded and a structured log message is emitted:

```text
[TempStorage] ProcessHashListJob discarded after retries — [TempStorage] Not enough temp
storage to download wordlist.txt (524288000 bytes required, 104857600 bytes available
in /tmp). Action: increase tmpfs size or reduce Sidekiq concurrency.
See docs/deployment/docker-storage-and-tmp.md
```

**If you see this in logs**, the tmpfs is persistently too small for the files being processed. Either:

1. Increase the tmpfs size (and container memory limit) to accommodate your largest files
2. Reduce Sidekiq concurrency to limit concurrent downloads
3. Switch to the TMPDIR volume approach for disk-backed temp storage

### What the check does NOT do

The pre-download check is a best-effort safeguard, not a guarantee:

- It checks available space at a single point in time — concurrent jobs may consume space between the check and the download
- It does not reserve space; another job could claim the space after the check passes
- If `Sys::Filesystem.stat` fails (e.g., unsupported filesystem), the check is skipped and the download proceeds normally

The tmpfs mount remains the primary defense. The pre-download check provides early failure with clear diagnostics rather than allowing a download to fail partway through.

## Alternative: TMPDIR Redirect

Instead of tmpfs, you can redirect temp files to a persistent Docker volume:

```yaml
sidekiq:
  environment:
    TMPDIR: /rails/tmp
  volumes:
    - sidekiq-tmp:/rails/tmp
    - storage:/rails/storage

volumes:
  sidekiq-tmp:
```

**Trade-offs:**

- Temp files persist across container restarts (requires periodic cleanup)
- No RAM pressure — uses disk instead of memory
- Slower I/O compared to tmpfs
- Shared volume across replicas could cause conflicts (use per-replica volumes if scaling)

This approach is better when memory is scarce but disk is plentiful.

## Verification

Confirm the tmpfs mounts inside a running Sidekiq container:

```bash
# Development
docker compose exec sidekiq df -h /tmp /rails/tmp

# Production
docker compose -f docker-compose-production.yml exec sidekiq df -h /tmp /rails/tmp
```

Expected output shows `tmpfs` as the filesystem type for both paths:

```text
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           512M     0  512M   0% /tmp
tmpfs           256M     0  256M   0% /rails/tmp
```

## Monitoring

Watch for signs that the tmpfs is filling up:

```bash
# Check current usage of both temp directories
docker compose exec sidekiq df -h /tmp /rails/tmp

# Monitor /tmp in real-time (blob downloads)
docker compose exec sidekiq watch -n 5 'df -h /tmp && echo "---" && ls -la /tmp'

# Check /rails/tmp usage (framework temp files)
docker compose exec sidekiq du -sh /rails/tmp/*
```

If tmpfs usage regularly exceeds 80%, consider:

1. Increasing the tmpfs size (and container memory limit)
2. Reducing Sidekiq concurrency to limit concurrent blob downloads
3. Switching to the TMPDIR volume approach

## Recovery

If a Sidekiq container hits `Errno::ENOSPC`:

1. **Restart the container** — tmpfs is cleared automatically on restart:

   ```bash
   docker compose -f docker-compose-production.yml restart sidekiq
   ```

2. **Check for stuck jobs** — large temp files from failed jobs may linger until the container restarts.

3. **Review job logs** — identify which blobs triggered the space exhaustion and consider whether the tmpfs size needs increasing.
