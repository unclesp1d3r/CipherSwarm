# Air-Gapped Deployment Guide

This guide covers deploying CipherSwarm in air-gapped (isolated) environments with no Internet access. CipherSwarm is designed for lab environments and supports fully offline operation.

## Prerequisites

- Docker and Docker Compose installed on the air-gapped system
- Sufficient disk space for Docker images (~2 GB) and data volumes
- Sufficient RAM for Sidekiq tmpfs mounts — the tmpfs must be at least as large as your largest attack file (wordlist, hash list, etc.) and ideally several times larger for concurrent processing (see [Docker Storage and /tmp Management](docker-storage-and-tmp.md) for sizing details)
- Access to an Internet-connected system for initial image export

## Step 1: Export Docker Images (Internet-Connected System)

On a system with Internet access, pull and save all required images:

```bash
# Pull the latest images
docker pull ghcr.io/unclesp1d3r/cipherswarm:latest
docker pull postgres:latest
docker pull redis:latest

# Save images to tar archives
docker save ghcr.io/unclesp1d3r/cipherswarm:latest -o cipherswarm.tar
docker save postgres:latest -o postgres.tar
docker save redis:latest -o redis.tar
```

Transfer the `.tar` files and the CipherSwarm source repository to the air-gapped system via USB drive, network share, or other approved transfer method.

## Step 2: Load Docker Images (Air-Gapped System)

On the air-gapped system, load the images:

```bash
docker load -i cipherswarm.tar
docker load -i postgres.tar
docker load -i redis.tar
```

Verify all images are loaded:

```bash
docker images | grep -E "cipherswarm|postgres|redis"
```

## Step 3: Configure Environment

Create a `.env` file in the CipherSwarm project root. Use the provided `.env.example` as a template:

```bash
# Copy the example file
cp .env.example .env

# Edit with your values
nano .env
```

**Required Variables for Air-Gapped Deployment:**

```bash
# Required (production will fail to start if these are not set)
RAILS_MASTER_KEY=<your-master-key>
POSTGRES_PASSWORD=<strong-password>
APPLICATION_HOST=<your-hostname>
TUSD_HOOK_SECRET=<shared-secret>

# Important for air-gapped environments
DISABLE_SSL=true  # Unless you have internal SSL certificates
ACTIVE_STORAGE_SERVICE=local
REDIS_URL=redis://redis-db:6379/0
```

**Variable Details:**

- **RAILS_MASTER_KEY**: Found in `config/master.key` on the system where the app was originally configured. Transfer this file securely.
- **POSTGRES_PASSWORD**: Database password. Strictly enforced as required — Docker Compose will fail validation if not set.
- **APPLICATION_HOST**: Hostname used to access the application (e.g., `cipherswarm.lab.local`). Provides DNS rebinding protection in production environments.
- **TUSD_HOOK_SECRET**: Shared secret for authenticating tusd webhook requests. Generate with `openssl rand -hex 32`. Prevents unauthorized cache poisoning attacks.

For complete documentation of all environment variables, see [Environment Variables Reference](environment-variables.md).

### Default Local Storage

By default, CipherSwarm uses local disk storage. Files are stored at `/rails/storage` inside the web container, backed by a Docker volume. To inspect or back up stored files:

```bash
docker compose -f docker-compose-production.yml exec web ls -la /rails/storage
```

### Optional: S3-Compatible Storage

To use S3-compatible storage instead of local disk, you must deploy an S3-compatible service within the air-gapped environment. Popular options:

| Service                                             | Image                 | Notes                                                                                                   |
| --------------------------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------- |
| [MinIO](https://min.io/)                            | `minio/minio`         | Widely adopted, simple single-binary deployment. Now requires a paid license for production use (AGPL). |
| [SeaweedFS](https://github.com/seaweedfs/seaweedfs) | `chrislusf/seaweedfs` | Apache 2.0 licensed, S3 gateway mode, lightweight.                                                      |
| [Garage](https://garagehq.deuxfleurs.fr/)           | `dxflrs/garage`       | AGPL, designed for self-hosting, geo-distributed.                                                       |

**1. Export the storage service image** (on the Internet-connected system, during Step 1):

```bash
# MinIO example — substitute your chosen service
docker pull minio/minio:latest
docker save minio/minio:latest -o storage-service.tar

# SeaweedFS example
# docker pull chrislusf/seaweedfs:latest
# docker save chrislusf/seaweedfs:latest -o storage-service.tar
```

**2. Load the image** (on the air-gapped system, during Step 2):

```bash
docker load -i storage-service.tar
```

**3. Add the storage service** to your `docker-compose-production.yml`. Example for MinIO:

```yaml
services:
  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${AWS_ACCESS_KEY_ID}
      MINIO_ROOT_PASSWORD: ${AWS_SECRET_ACCESS_KEY}
    volumes:
      - minio-data:/data
    ports:
      - 9000:9000
      - 9001:9001
    healthcheck:
      test: [CMD, mc, ready, local]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  minio-data:
```

For SeaweedFS, run with `weed server -s3` and point `AWS_ENDPOINT` at the S3 gateway port (default 8333).

**4. Set environment variables** in `.env`:

```bash
ACTIVE_STORAGE_SERVICE=s3
AWS_ACCESS_KEY_ID=<access-key>
AWS_SECRET_ACCESS_KEY=<secret-key>
AWS_BUCKET=application
AWS_ENDPOINT=http://minio:9000       # or http://seaweedfs:8333
AWS_FORCE_PATH_STYLE=true
AWS_REGION=us-east-1
```

All `AWS_*` credentials are required when using S3 storage — the application will fail at startup if they are missing.

**5. Create the bucket** before first use:

```bash
# MinIO CLI example
docker compose -f docker-compose-production.yml exec minio \
  mc alias set local http://localhost:9000 <access-key> <secret-key>
docker compose -f docker-compose-production.yml exec minio \
  mc mb local/application
```

## Step 4: Deploy Services

```bash
docker compose -f docker-compose-production.yml up -d
```

Verify all services started:

```bash
docker compose -f docker-compose-production.yml ps
```

All services should show a healthy status: `web`, `postgres-db`, `redis-db`, `sidekiq`.

## Step 5: Run Database Setup

On first deployment, create and migrate the database using the `RUN_DB_PREPARE` flag:

```bash
docker compose -f docker-compose-production.yml run --rm -e RUN_DB_PREPARE=true web bin/rails db:create db:migrate db:seed
```

**Why `RUN_DB_PREPARE=true`?**

The `RUN_DB_PREPARE` environment variable prevents database migration races in scaled deployments. Without this flag, multiple web replicas could attempt to run migrations simultaneously, causing deadlocks and corruption. By requiring an explicit flag, migrations run exactly once during initial setup or upgrades, not on every container start.

On subsequent deployments (upgrades), run migrations only:

```bash
docker compose -f docker-compose-production.yml run --rm -e RUN_DB_PREPARE=true web bin/rails db:migrate
```

**Scaling Guidance:**

If running multiple web replicas (e.g., for high availability):

1. Run database migrations once with `RUN_DB_PREPARE=true` before scaling.
2. Do not set `RUN_DB_PREPARE=true` on the regular web service containers.
3. Scale web replicas after migrations complete.

This ensures migrations run exactly once, avoiding race conditions.

## Step 6: Verify Deployment

1. **Health endpoint:**

   ```bash
   curl http://localhost/up
   # Expected: HTTP 200
   ```

2. **System health dashboard:**

   Navigate to `http://<host-ip>/system_health` and verify all services show healthy status.

3. **Login:**

   Navigate to `http://<host-ip>` and sign in with admin credentials created during seed.

## Air-Gapped Verification Checklist

Run through this checklist after deployment to confirm full offline operation:

- [ ] All CSS/JS assets load (no CDN or external requests in browser Network tab)
- [ ] All fonts render correctly (Bootstrap Icons are bundled in the asset pipeline)
- [ ] All images and icons display (no broken image placeholders)
- [ ] Docker Compose starts all services without Internet
- [ ] Every page loads without external network requests (check browser DevTools)
- [ ] Asset precompilation completed (`public/assets/` contains compiled files)
- [ ] Health check endpoints respond (`/up` and `/system_health`)
- [ ] Agent API is accessible from agent hosts (`POST /api/v1/client/authenticate`)
- [ ] File uploads and downloads work (hash lists, word lists, rule lists)
- [ ] Documentation is available locally in the `docs/` directory

## Migrating from S3/MinIO to Local Disk Storage

If your deployment previously used S3-compatible storage (MinIO, SeaweedFS, AWS S3) and you want to switch to local disk storage, use the built-in migration rake task.

### Prerequisites

- The S3 service must still be accessible (files need to be downloaded)
- Sufficient disk space on the Docker volume for all stored files
- If using the old `:minio` config that no longer exists in `storage.yml`, either:
  - Add a temporary `minio:` entry to `config/storage.yml` pointing to your MinIO instance, or
  - Use `SOURCE_SERVICE=s3` if your `s3:` entry already points to the same backend

### Running the Migration

**1. Preview what will be migrated (recommended first step):**

```bash
docker compose -f docker-compose-production.yml exec web \
  bin/rails storage:migrate_to_local DRY_RUN=true
```

**2. Run the actual migration:**

```bash
docker compose -f docker-compose-production.yml exec web \
  bin/rails storage:migrate_to_local
```

**3. If blobs reference an old service name (e.g., "minio") but your storage.yml uses "s3":**

```bash
docker compose -f docker-compose-production.yml exec web \
  bin/rails storage:migrate_to_local SOURCE_SERVICE=s3
```

### Safety

- **Idempotent**: Safe to re-run after partial failure. Already-migrated blobs are skipped.
- **Checksum verified**: Each file is verified against its stored checksum before writing to disk.
- **Non-destructive**: Source files in S3 are not deleted. Remove them manually after verifying the migration.
- **Interruptible**: Ctrl+C stops gracefully and prints a progress summary.

### Post-Migration

After successful migration:

1. Update `.env` to set `ACTIVE_STORAGE_SERVICE=local` (or remove the variable — local is the default)
2. Remove `AWS_*` environment variables if S3 is no longer needed
3. Remove the S3-compatible storage service from your Docker Compose file
4. Verify file downloads work in the web UI

## Upgrading in Air-Gapped Environments

1. Export the new CipherSwarm image on the Internet-connected system:

   ```bash
   docker pull ghcr.io/unclesp1d3r/cipherswarm:latest
   docker save ghcr.io/unclesp1d3r/cipherswarm:latest -o cipherswarm.tar
   ```

2. Transfer the tar file to the air-gapped system.

3. Load the new image:

   ```bash
   docker load -i cipherswarm.tar
   ```

4. Back up the database:

   ```bash
   docker compose -f docker-compose-production.yml exec postgres-db \
     pg_dump -U cipherswarm -d cipherswarm > backup_$(date +%Y%m%d_%H%M%S).sql
   ```

5. Stop application services (keep the database running):

   ```bash
   docker compose -f docker-compose-production.yml stop web sidekiq
   ```

6. Run migrations with the `RUN_DB_PREPARE` flag:

   ```bash
   docker compose -f docker-compose-production.yml run --rm -e RUN_DB_PREPARE=true web bin/rails db:migrate
   ```

7. Restart all services:

   ```bash
   docker compose -f docker-compose-production.yml up -d
   ```

8. Verify with the checklist above.

## Troubleshooting

| Symptom                                | Cause                                                                         | Solution                                                                                                                                                                                                                                                                                                                        |
| -------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Assets fail to load (404s)             | Precompilation not run                                                        | Run `bin/rails assets:precompile` inside the web container                                                                                                                                                                                                                                                                      |
| Storage connection refused             | Wrong AWS_ENDPOINT                                                            | Verify `AWS_ENDPOINT` points to the correct S3-compatible host                                                                                                                                                                                                                                                                  |
| Agents cannot connect                  | Network/firewall                                                              | Verify port 80 is open between agent hosts and the CipherSwarm host                                                                                                                                                                                                                                                             |
| Database connection error              | PostgreSQL not ready                                                          | Wait for `postgres-db` health check to pass before starting web                                                                                                                                                                                                                                                                 |
| Redis connection error                 | Redis not started                                                             | Check `redis-db` container status and logs                                                                                                                                                                                                                                                                                      |
| Sidekiq not processing                 | Redis unreachable                                                             | Verify `REDIS_URL` points to `redis://redis-db:6379`                                                                                                                                                                                                                                                                            |
| Sidekiq jobs fail with `Errno::ENOSPC` | `/tmp` on overlay filesystem exhausted by large Active Storage blob downloads | Add `tmpfs: - /tmp:size=512m,mode=1777` to the sidekiq service (production default). If processing very large files, increase both tmpfs size and the container memory limit proportionally (e.g., `size=1g` with a 2 GB memory limit). See [Docker Storage and /tmp Management](docker-storage-and-tmp.md) for sizing details. |

## Rollback Procedure

If a deployment causes issues:

1. Stop services:

   ```bash
   docker compose -f docker-compose-production.yml down
   ```

2. Load the previous CipherSwarm image:

   ```bash
   docker load -i cipherswarm-previous.tar
   docker tag <previous-image-id> ghcr.io/unclesp1d3r/cipherswarm:latest
   ```

3. Rollback database migrations (adjust STEP count to match the number of new migrations):

   ```bash
   docker compose -f docker-compose-production.yml run --rm web bin/rails db:rollback STEP=4
   ```

4. Or restore from backup:

   ```bash
   docker compose -f docker-compose-production.yml exec postgres-db \
     psql -U cipherswarm -d cipherswarm < backup_YYYYMMDD_HHMMSS.sql
   ```

5. Restart services:

   ```bash
   docker compose -f docker-compose-production.yml up -d
   ```
