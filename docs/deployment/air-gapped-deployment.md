# Air-Gapped Deployment Guide

This guide covers deploying CipherSwarm in air-gapped (isolated) environments with no Internet access. CipherSwarm is designed for lab environments and supports fully offline operation.

## Prerequisites

- Docker and Docker Compose installed on the air-gapped system
- Sufficient disk space for Docker images (~2 GB) and data volumes
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

Create a `.env` file in the CipherSwarm project root (if not already present):

```bash
# Required
RAILS_MASTER_KEY=<your-master-key>
POSTGRES_PASSWORD=<strong-password>
```

The `RAILS_MASTER_KEY` is found in `config/master.key` on the system where the app was originally configured. Transfer this file securely.

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

On first deployment, create and migrate the database:

```bash
docker compose -f docker-compose-production.yml run --rm web bin/rails db:create db:migrate db:seed
```

On subsequent deployments (upgrades), run migrations only:

```bash
docker compose -f docker-compose-production.yml run --rm web bin/rails db:migrate
```

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

6. Run migrations:

   ```bash
   docker compose -f docker-compose-production.yml run --rm web bin/rails db:migrate
   ```

7. Restart all services:

   ```bash
   docker compose -f docker-compose-production.yml up -d
   ```

8. Verify with the checklist above.

## Troubleshooting

| Symptom                    | Cause                  | Solution                                                            |
| -------------------------- | ---------------------- | ------------------------------------------------------------------- |
| Assets fail to load (404s) | Precompilation not run | Run `bin/rails assets:precompile` inside the web container          |
| Storage connection refused | Wrong AWS_ENDPOINT     | Verify `AWS_ENDPOINT` points to the correct S3-compatible host      |
| Agents cannot connect      | Network/firewall       | Verify port 80 is open between agent hosts and the CipherSwarm host |
| Database connection error  | PostgreSQL not ready   | Wait for `postgres-db` health check to pass before starting web     |
| Redis connection error     | Redis not started      | Check `redis-db` container status and logs                          |
| Sidekiq not processing     | Redis unreachable      | Verify `REDIS_URL` points to `redis://redis-db:6379`                |

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
