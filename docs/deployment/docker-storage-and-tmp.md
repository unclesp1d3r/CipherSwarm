# Docker Storage and /tmp Management

## Problem

Sidekiq containers can exhaust their overlay filesystem when processing large Active Storage blobs (hash lists, wordlists, rule files). The failure surfaces as `Errno::ENOSPC` in jobs like `ProcessHashListJob`.

## Root Cause

Background jobs (e.g., `ProcessHashListJob`, `CountFileLinesJob`) must download attack resources — hash lists, wordlists, rule files, mask lists — from storage (local disk or S3) to a temporary location for analysis during ingest. Active Storage's `blob.open` streams the entire file into `Dir.tmpdir` (defaults to `/tmp`), processes it, and deletes the temp file when the job completes. The files are **not** retained after the job finishes; this is only needed for initial ingest and analysis.

In a Docker container, `/tmp` lives on the container's writable overlay layer — a thin, size-limited filesystem backed by the host's Docker storage driver. Under sustained load (multiple Sidekiq threads downloading and processing large files concurrently), the overlay fills up and subsequent writes fail.

This applies regardless of storage backend — even when using S3, Active Storage must download the full blob to local temp storage before the job can read its contents.

The problem is amplified in production where:

- Sidekiq runs with concurrency 10 (up to 10 concurrent blob downloads per container)
- Multiple Sidekiq replicas share the same image but each has its own overlay
- Attack resources (especially wordlists) can be hundreds of megabytes or larger

## Fix: tmpfs Mount

Both `docker-compose.yml` and `docker-compose-production.yml` mount a `tmpfs` filesystem at `/tmp` on the Sidekiq service. This keeps temp files in RAM, automatically clears on container restart, and isolates temp storage from the overlay filesystem.

```yaml
sidekiq:
  tmpfs:
    - /tmp:size=512m,mode=1777
```

- **`size`** — Maximum size of the tmpfs. Counts against the container's memory limit.
- **`mode=1777`** — Standard `/tmp` permissions (world-writable with sticky bit).

## Sizing Guidance

The right tmpfs size depends on your deployment scale and the size of files your campaigns process. Use this table as a starting point:

| Deployment scale          | Sidekiq replicas | Concurrency | Container memory limit | Recommended tmpfs size |
| ------------------------- | ---------------- | ----------- | ---------------------- | ---------------------- |
| Development / single node | 1                | 5           | (unlimited)            | 1 GB                   |
| Small production          | 1-2              | 10          | 1 GB                   | 512 MB                 |
| Medium production         | 4                | 10          | 1 GB                   | 512 MB                 |
| Large production          | 8+               | 10          | 2 GB+                  | 1-2 GB                 |

**Key constraint:** tmpfs memory is subtracted from the container's memory limit (`deploy.resources.limits.memory`). With the default 1 GB memory limit and 512 MB tmpfs, the Ruby process has ~512 MB for heap, stack, and gem memory. If you increase tmpfs, increase the memory limit proportionally.

### Minimum size requirement

The tmpfs **must** be at least as large as your single largest attack file (word list, mask list, rule file, or hash list). Active Storage downloads the entire blob to `/tmp` before processing, so a file that exceeds the tmpfs size will always fail with `Errno::ENOSPC` regardless of concurrency.

In practice, the tmpfs should be **several times larger** than your largest file because Sidekiq processes multiple jobs concurrently — each downloading its own blob to `/tmp` at the same time.

### Estimating tmpfs needs

```
minimum_tmpfs  = largest_single_file
recommended    = largest_single_file * sidekiq_concurrency
```

For example, if your largest wordlist is 200 MB and Sidekiq concurrency is 10, peak tmp usage could reach 2 GB. The absolute minimum tmpfs would be 200 MB (enough for one file), but 512 MB–2 GB is recommended to handle concurrent downloads plus Ruby's own temp files and OS overhead.

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

Confirm the tmpfs is mounted inside a running Sidekiq container:

```bash
# Development
docker compose exec sidekiq df -h /tmp

# Production
docker compose -f docker-compose-production.yml exec sidekiq df -h /tmp
```

Expected output shows `tmpfs` as the filesystem type with the configured size:

```
Filesystem      Size  Used Avail Use% Mounted on
tmpfs           512M     0  512M   0% /tmp
```

## Monitoring

Watch for signs that the tmpfs is filling up:

```bash
# Check current usage
docker compose exec sidekiq du -sh /tmp

# Monitor in real-time
docker compose exec sidekiq watch -n 5 'df -h /tmp && echo "---" && ls -la /tmp'
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

## Pre-Download Space Check

All background jobs that download Active Storage blobs (`ProcessHashListJob`, `CountFileLinesJob`, `CalculateMaskComplexityJob`) check available temp storage space before starting the download. If the available space in `Dir.tmpdir` is less than or equal to the blob's size, the job raises `InsufficientTempStorageError` instead of attempting the download.

This check prevents partial downloads that would fill the tmpfs and fail mid-transfer with `Errno::ENOSPC`.

**Retry behavior:** Jobs retry 5 times with increasing delays (polynomial backoff). This handles transient space pressure when multiple jobs are downloading concurrently — as other jobs finish and clean up their temp files, space becomes available.

**Discard behavior:** After 5 failed attempts, the job is discarded and a structured log message is emitted:

```text
[TempStorage] ProcessHashListJob discarded after retries — [TempStorage] Not enough temp
storage to download wordlist.txt (524288000 bytes required, 104857600 bytes available
in /tmp). Action: increase tmpfs size or reduce Sidekiq concurrency.
See docs/deployment/docker-storage-and-tmp.md
```

If you see this in logs, either:

1. Increase the tmpfs size (and container memory limit) to accommodate your largest files
2. Reduce Sidekiq concurrency to limit concurrent downloads
3. Switch to the TMPDIR volume approach for disk-backed temp storage
