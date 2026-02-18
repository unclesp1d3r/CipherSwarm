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
docker pull minio/minio:latest

# Save images to tar archives
docker save ghcr.io/unclesp1d3r/cipherswarm:latest -o cipherswarm.tar
docker save postgres:latest -o postgres.tar
docker save redis:latest -o redis.tar
docker save minio/minio:latest -o minio.tar
```

Transfer the `.tar` files and the CipherSwarm source repository to the air-gapped system via USB drive, network share, or other approved transfer method.

## Step 2: Load Docker Images (Air-Gapped System)

On the air-gapped system, load the images:

```bash
docker load -i cipherswarm.tar
docker load -i postgres.tar
docker load -i redis.tar
docker load -i minio.tar
```

Verify all images are loaded:

```bash
docker images | grep -E "cipherswarm|postgres|redis|minio"
```

## Step 3: Configure Environment

Create a `.env` file in the CipherSwarm project root (if not already present):

```bash
# Required
RAILS_MASTER_KEY=<your-master-key>
POSTGRES_PASSWORD=<strong-password>

# Set to the IP address agents will use to reach MinIO
MINIO_PUBLIC_IP=<host-ip-or-hostname>
```

The `RAILS_MASTER_KEY` is found in `config/master.key` on the system where the app was originally configured. Transfer this file securely.

## Step 4: Deploy Services

```bash
docker compose -f docker-compose-production.yml up -d
```

Verify all services started:

```bash
docker compose -f docker-compose-production.yml ps
```

All services should show a healthy status: `web`, `postgres-db`, `redis-db`, `minio`, `sidekiq`.

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
- [ ] File uploads and downloads work via MinIO (hash lists, word lists, rule lists)
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
| MinIO connection refused   | Wrong MINIO_ENDPOINT   | Set `MINIO_PUBLIC_IP` to the host IP reachable by agents            |
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
