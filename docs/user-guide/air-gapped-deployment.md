# Air-Gapped Deployment Guide

This guide covers deploying and operating CipherSwarm in air-gapped (network-isolated) environments where no Internet access is available.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Deployment Steps](#deployment-steps)
- [Air-Gapped Deployment Validation Checklist](#air-gapped-deployment-validation-checklist)
- [Validation Procedures](#validation-procedures)
- [Troubleshooting Offline Deployment](#troubleshooting-offline-deployment)
- [Maintenance in Air-Gapped Environments](#maintenance-in-air-gapped-environments)
- [Security Considerations](#security-considerations)

---

## Overview

An air-gapped deployment runs CipherSwarm entirely within an isolated network with no Internet connectivity. This is common in:

- Classified or sensitive environments
- Compliance-restricted networks (PCI-DSS, HIPAA, government)
- Secure testing labs
- Environments with strict data exfiltration controls

CipherSwarm V2 is designed to function fully offline. All assets, fonts, icons, and dependencies are bundled within the application containers, with no external CDN or API calls required.

---

## Prerequisites

### System Requirements

- Docker and Docker Compose installed on all nodes
- Sufficient disk space for container images (~2 GB for images, plus space for data volumes)
- Sufficient disk space for wordlists, rules, and hash data
- Sufficient RAM for tmpfs mounts: minimum 768MB per service for tmpfs (512MB for /tmp + 256MB for /rails/tmp). For deployments processing large hash lists (>100MB attack files), allocate 2-4GB total tmpfs per service.
- Network connectivity between CipherSwarm server components (internal only)
- Network connectivity between agents and the CipherSwarm server (internal only)

### Required Container Images

Transfer the following images to the air-gapped environment:

- CipherSwarm application image
- PostgreSQL image
- Redis image
- CipherSwarm agent image (for each agent node)

### Image Transfer Methods

Since there is no Internet access in the air-gapped environment, transfer images using one of these methods:

#### Method 1: Docker Save/Load

On a connected machine:

```bash
# Pull and save images
docker pull cipherswarm:latest
docker pull postgres:16
docker pull redis:7

docker save cipherswarm:latest postgres:16 redis:7 \
  -o cipherswarm-images.tar
```

On the air-gapped machine:

```bash
# Load images
docker load -i cipherswarm-images.tar
```

#### Method 2: Private Registry

If your air-gapped network has a private container registry:

1. Push images to the private registry from a connected machine
2. Update `docker-compose.yml` to reference the private registry URLs
3. Pull images from the private registry on the air-gapped nodes

### Pre-Loading Resources

Transfer wordlists, rule files, and other resources to the air-gapped environment before deployment:

1. Package all resource files into an archive
2. Transfer the archive to the air-gapped environment
3. Upload resources through the CipherSwarm web interface after deployment
4. Alternatively, mount resource directories directly into the storage volume

---

## Deployment Steps

### Step 1: Transfer Container Images

Transfer all required container images to the air-gapped environment using one of the methods described in [Prerequisites](#image-transfer-methods).

### Step 2: Configure Docker Compose

Ensure the `docker-compose.yml` file does not reference any external registries or services. The docker-compose configuration includes tmpfs mounts at `/tmp` and `/rails/tmp` for both web and sidekiq services. These are memory-backed filesystems required to prevent overlay filesystem exhaustion during Active Storage blob downloads (hash lists, wordlists, rule files). The `/tmp` mount stores Active Storage temporary files during ingest jobs, while `/rails/tmp` holds Rails framework temp files and Bootsnap cache. Tmpfs allocation counts against container memory limits—see the [tmpfs sizing section](#tmpfs-sizing-for-large-files) below for guidance on adjusting sizes based on your largest attack files.

```yaml
services:
  web:
    image: cipherswarm:latest  # Use local image, not registry URL
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=<generate-a-secure-key>
      - DATABASE_URL=postgres://cipherswarm:<secure-password>@postgres-db:5432/cipherswarm
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - postgres-db
      - redis
    tmpfs:
      - /tmp:size=512m,mode=1777
      - /rails/tmp:size=256m,mode=1777
    volumes:
      - storage:/rails/storage

  postgres-db:
    image: postgres:16
    environment:
      POSTGRES_USER: cipherswarm
      POSTGRES_PASSWORD: <secure-password>
      POSTGRES_DB: cipherswarm
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7
    volumes:
      - redis_data:/data

  sidekiq:
    image: cipherswarm:latest
    command: bundle exec sidekiq
    environment:
      - RAILS_ENV=production
      - DATABASE_URL=postgres://cipherswarm:<secure-password>@postgres-db:5432/cipherswarm
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - postgres-db
      - redis
    tmpfs:
      - /tmp:size=512m,mode=1777
      - /rails/tmp:size=256m,mode=1777
    volumes:
      - storage:/rails/storage

volumes:
  storage:
  postgres_data:
  redis_data:
```

#### tmpfs Sizing for Large Files

The default tmpfs configuration allocates 512MB for `/tmp` and 256MB for `/rails/tmp` on each service. This works for most deployments but may need adjustment based on the size of attack files you process.

**Minimum requirement:** The `/tmp` tmpfs must be at least as large as your single largest attack file (wordlist, hash list, rule file, or mask list). Active Storage downloads the entire file to `/tmp` before processing, so a file larger than the tmpfs will always fail with `Errno::ENOSPC`.

**Recommended sizing:** Multiply your largest file size by the Sidekiq concurrency setting (default 10) to handle concurrent downloads. For example, if your largest wordlist is 200MB, a 2GB `/tmp` tmpfs allows up to 10 concurrent ingest jobs without space pressure.

**Memory constraint:** tmpfs memory is subtracted from the container's total memory limit. If you increase tmpfs sizes, increase the container memory limit proportionally. For detailed sizing guidance, tmpfs vs disk trade-offs, and pre-download space check behavior, see [Docker Storage and tmpfs Management](../deployment/docker-storage-and-tmp.md).

### Step 3: Configure Environment Variables

Create a `.env` file in the CipherSwarm project root. Copy the provided `.env.example` file as a starting point and customize values for your air-gapped environment:

```bash
# Copy the example file
cp .env.example .env

# Edit with your values
nano .env
```

**Required Variables for Air-Gapped Deployment:**

```bash
# Required
RAILS_MASTER_KEY=<your-master-key>
POSTGRES_PASSWORD=<strong-password>
APPLICATION_HOST=<your-hostname>

# Important for air-gapped environments
DISABLE_SSL=true  # Unless you have internal SSL certificates
ACTIVE_STORAGE_SERVICE=local
REDIS_URL=redis://redis:6379/0
```

The `RAILS_MASTER_KEY` is found in `config/master.key` on the system where the app was originally configured. Transfer this file securely to the air-gapped environment.

For comprehensive documentation of all environment variables, including deployment scenarios and troubleshooting, see the [Environment Variables Reference](../deployment/environment-variables.md).

### Step 4: Verify Asset Precompilation

Before starting the application, verify that all assets are bundled in the container:

```bash
# Check that assets are precompiled in the container
docker run --rm cipherswarm:latest ls public/assets/

# Verify CSS files exist
docker run --rm cipherswarm:latest ls public/assets/*.css

# Verify JavaScript files exist
docker run --rm cipherswarm:latest ls public/assets/*.js
```

### Step 5: Start the Stack

```bash
# Start all services
docker compose up -d

# Verify all containers are running
docker compose ps

# Run database migrations
docker compose exec web bin/rails db:create db:migrate

# Seed initial data (admin user, etc.)
docker compose exec web bin/rails db:seed
```

### Step 6: Verify the Deployment

1. Access the web interface at `http://<server-ip>:3000`
2. Log in with the default admin credentials (from seed data)
3. Check the system health dashboard for all green statuses
4. Register an agent and verify connectivity

### Step 7: Bundle Documentation (Optional)

To make documentation available offline within the deployment:

```bash
# Copy user guide into a servable location
docker compose exec web cp -r docs/user-guide/ public/docs/

# Or mount documentation as a volume
# Add to docker-compose.yml under web service:
#   volumes:
#     - ./docs:/app/public/docs:ro
```

---

## Air-Gapped Deployment Validation Checklist

Use this checklist to verify that your air-gapped deployment is fully functional. All 10 items must pass.

- [ ] **1. All CSS/JS assets bundled in container (no CDN references)**

  Verify that no CSS or JavaScript files reference external CDNs (e.g., cdnjs, unpkg, jsdelivr). All assets must be served from the application container.

- [ ] **2. All fonts embedded or using system fonts**

  Verify that no font files are loaded from external sources (Google Fonts, Adobe Fonts, etc.). Fonts must be bundled in the asset pipeline or use system font stacks.

- [ ] **3. All icons/images included in asset pipeline**

  Verify that all icons (Bootstrap Icons, custom SVGs) and images are bundled in the container. No external icon CDNs should be referenced.

- [ ] **4. Docker Compose works without Internet access**

  Start the full stack with network isolation and verify all services come up successfully. No container should fail due to missing external dependencies.

- [ ] **5. All pages load and function without external requests**

  Navigate through all major pages (dashboard, campaigns, agents, resources, admin) and verify that no browser console errors reference failed external requests.

- [ ] **6. Asset precompilation successful in build**

  Verify that `bin/rails assets:precompile` completes without errors during the container build process. The `public/assets/` directory should contain all compiled assets.

- [ ] **7. Health check endpoints work in isolated network**

  Verify that the system health dashboard reports correct status for all services (PostgreSQL, Redis, Storage, Application) within the isolated network.

- [ ] **8. Agent API accessible from isolated agents**

  From an agent within the air-gapped network, verify that the agent API endpoints respond correctly:

  - Authentication: `GET /api/v1/client/authenticate`
  - Configuration: `GET /api/v1/client/configuration`
  - Task assignment: `GET /api/v1/client/tasks/new`

- [ ] **9. File uploads/downloads work (no external S3 calls)**

  Upload a test wordlist through the web interface and verify it is stored correctly. Download it from an agent to verify the full round-trip.

- [ ] **10. Documentation accessible offline (bundled in container or separate package)**

  Verify that the user guide documentation is accessible without Internet access, either bundled within the container or provided as a separate offline package.

---

## Validation Procedures

### Validating Item 1: CSS/JS Assets

```bash
# Search for external URLs in compiled assets
docker compose exec web \
  grep -r "https://" public/assets/ --include="*.css" --include="*.js" | \
  grep -v "localhost" | grep -v "127.0.0.1"

# Expected: No output (no external references)
```

### Validating Item 2: Fonts

```bash
# Check for external font references in CSS
docker compose exec web \
  grep -ri "fonts.googleapis\|fonts.gstatic\|use.typekit\|fast.fonts" \
  public/assets/ --include="*.css"

# Expected: No output

# Verify local font files exist (if using custom fonts)
docker compose exec web ls public/assets/*.woff2 2>/dev/null
```

### Validating Item 3: Icons and Images

```bash
# Check for external icon CDN references
docker compose exec web \
  grep -ri "cdn.jsdelivr\|cdnjs.cloudflare\|unpkg.com" \
  public/assets/ --include="*.css" --include="*.js"

# Expected: No output

# Verify Bootstrap Icons are bundled
docker compose exec web ls public/assets/bootstrap-icons* 2>/dev/null
```

### Validating Item 4: Docker Compose Without Internet

```bash
# Disconnect from the Internet (or use network namespace isolation)
# Then start the stack
docker compose down
docker compose up -d

# Verify all containers are healthy
docker compose ps
# All services should show "Up" or "healthy" status
```

### Validating Item 5: No External Requests

1. Open the browser developer tools (F12)
2. Go to the **Network** tab
3. Navigate through each major page
4. Filter for failed requests
5. Verify no requests to external domains appear

### Validating Item 6: Asset Precompilation

```bash
# Build the container and check asset compilation
docker compose exec web bin/rails assets:precompile RAILS_ENV=production

# Verify manifest exists
docker compose exec web cat public/assets/.sprockets-manifest-*.json 2>/dev/null || \
  docker compose exec web ls public/assets/manifest-*.js 2>/dev/null
```

### Validating Item 7: Health Check Endpoints

1. Access the system health dashboard in the web interface
2. Verify all four services show green/healthy status
3. Alternatively, check programmatically:

```bash
# Check health endpoint
curl -s http://localhost:3000/system_health | head -20
```

### Validating Item 8: Agent API

```bash
# From within the air-gapped network
# Test authentication
curl -s -H "Authorization: Bearer <agent-token>" \
  http://<server-ip>:3000/api/v1/client/authenticate

# Test configuration retrieval
curl -s -H "Authorization: Bearer <agent-token>" \
  http://<server-ip>:3000/api/v1/client/configuration

# Test task request
curl -s -H "Authorization: Bearer <agent-token>" \
  http://<server-ip>:3000/api/v1/client/tasks/new
```

### Validating Item 9: File Upload/Download

1. Log in to the web interface
2. Navigate to **Resources** > **Wordlists**
3. Upload a small test wordlist file
4. Verify the upload completes successfully
5. From an agent, verify the resource can be downloaded via the API

### Validating Item 10: Offline Documentation

1. Verify documentation files are accessible:

```bash
# If bundled in the container
docker compose exec web ls docs/user-guide/

# If served via web
curl -s http://localhost:3000/docs/README.md
```

2. Alternatively, verify the documentation package was transferred to the air-gapped environment and is accessible via file browser or local web server.

---

## Troubleshooting Offline Deployment

### Asset Loading Failures

**Symptoms**: Pages load without styling, JavaScript errors in console.

**Solutions**:

1. Verify asset precompilation completed during build:

   ```bash
   docker compose exec web ls -la public/assets/
   ```

2. Check that `RAILS_SERVE_STATIC_FILES=true` is set in the environment

3. Verify the asset manifest file exists

4. Rebuild the container if assets are missing:

   ```bash
   docker compose build --no-cache web
   ```

### Font Rendering Issues

**Symptoms**: Icons appear as empty squares or text appears in a default font.

**Solutions**:

1. Verify font files are in the asset pipeline:

   ```bash
   docker compose exec web find public/assets -name "*.woff*" -o -name "*.ttf"
   ```

2. Check CSS `@font-face` declarations point to local paths

3. If using system fonts, verify the font stack includes appropriate fallbacks

4. Rebuild assets if fonts are missing

### Icon Display Problems

**Symptoms**: Bootstrap Icons or other icons appear as broken images or empty squares.

**Solutions**:

1. Verify the icon font/sprite files are bundled:

   ```bash
   docker compose exec web find public/assets -name "bootstrap-icons*"
   ```

2. Check that CSS references to icon fonts use relative paths

3. Verify no external CDN references exist for icon libraries

4. If using SVG icons, verify they are included in the asset pipeline

### Network Connectivity Errors

**Symptoms**: Services cannot connect to each other within the Docker network.

**Solutions**:

1. Verify Docker networking is functional:

   ```bash
   docker compose exec web ping postgres-db
   docker compose exec web ping redis
   ```

2. Check that service names in configuration match `docker-compose.yml` service names

3. Verify no firewall rules block inter-container communication

4. Check Docker DNS resolution:

   ```bash
   docker compose exec web nslookup postgres-db
   ```

### Temporary Storage Exhaustion

**Symptoms**: Sidekiq jobs fail with `Errno::ENOSPC` or `InsufficientTempStorageError` in logs. Jobs processing hash lists, wordlists, or rule files are discarded after retries.

**Cause**: The tmpfs mount at `/tmp` is too small for the attack files being processed. Active Storage downloads the entire blob to `/tmp` before the ingest job can process it. If the tmpfs is smaller than the file, or multiple concurrent jobs fill the available space, downloads fail with "No space left on device."

**Solutions**:

1. **Increase tmpfs size** in `docker-compose.yml` for sidekiq and web services. The size must be at least as large as your single largest attack file. For concurrent processing, multiply the largest file size by the Sidekiq concurrency setting (default 10).

   ```yaml
   sidekiq:
     tmpfs:
       - /tmp:size=2g,mode=1777  # Increase from default 512m
       - /rails/tmp:size=256m,mode=1777
   ```

2. **Increase container memory limit** proportionally—tmpfs memory is subtracted from the container's total memory allocation.

3. **Reduce Sidekiq concurrency** to limit the number of concurrent blob downloads:

   ```yaml
   sidekiq:
     environment:
       - SIDEKIQ_CONCURRENCY=5  # Default is 10
   ```

4. **Use disk-backed temp storage** instead of tmpfs by setting the `TMPDIR` environment variable and mounting a persistent volume. This trades memory pressure for disk I/O but removes the size constraint:

   ```yaml
   sidekiq:
     environment:
       - TMPDIR=/rails/tmp
     volumes:
       - sidekiq-tmp:/rails/tmp
       - storage:/rails/storage

   volumes:
     sidekiq-tmp:
   ```

For detailed tmpfs sizing guidance, monitoring, and recovery procedures, see [Docker Storage and tmpfs Management](../deployment/docker-storage-and-tmp.md).

---

## Maintenance in Air-Gapped Environments

### Updating Containers

Since there is no Internet access, container updates must be transferred manually:

1. On a connected machine, pull the new container images

2. Save images to a file using `docker save`

3. Transfer the file to the air-gapped environment

4. Load images using `docker load`

5. Restart services:

   ```bash
   docker compose down
   docker compose up -d
   docker compose exec web bin/rails db:migrate
   ```

### Backing Up Data

Regular backups are critical in air-gapped environments since recovery options are limited:

#### Database Backup

```bash
# Backup PostgreSQL
docker compose exec postgres-db \
  pg_dump -U cipherswarm cipherswarm > backup_$(date +%Y%m%d).sql

# Restore from backup
docker compose exec -T postgres-db \
  psql -U cipherswarm cipherswarm < backup_20260101.sql
```

#### Storage Backup

```bash
# Backup the storage Docker volume
docker run --rm \
  -v cipherswarm_storage:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/storage_backup.tar.gz /data
```

#### Full System Backup

```bash
# Stop services for consistent backup
docker compose stop

# Backup all volumes
for vol in storage postgres_data redis_data; do
  docker run --rm \
    -v cipherswarm_${vol}:/data \
    -v $(pwd)/backups:/backup \
    alpine tar czf /backup/${vol}_$(date +%Y%m%d).tar.gz /data
done

# Restart services
docker compose start
```

### Log Management

In air-gapped environments, logs cannot be shipped to external services:

1. Configure Docker log rotation:

   ```yaml
   # In docker-compose.yml, add to each service:
   logging:
     driver: json-file
     options:
       max-size: 50m
       max-file: '5'
   ```

2. Periodically archive and remove old logs

3. Monitor disk space usage to prevent log-related outages

4. Consider mounting a dedicated volume for logs

### Adding New Resources

To add new wordlists, rules, or other resources:

1. Transfer resource files to the air-gapped environment
2. Upload through the CipherSwarm web interface
3. Or copy files directly to the storage volume
4. Verify resources are accessible from agents

---

## Security Considerations

### Network Isolation

- Ensure the air-gapped network is truly isolated (no bridged connections)
- Use separate VLANs for CipherSwarm server components and agents
- Restrict inter-node communication to required ports only
- Monitor for unauthorized network connections

### Access Controls

- Use strong passwords for all services (PostgreSQL, Redis, admin accounts)
- Rotate passwords on a regular schedule
- Limit the number of administrator accounts
- Review audit logs regularly

### Data Protection

- All cracking results remain within the air-gapped environment
- Ensure physical security of the machines
- Encrypt backup media before any physical transport
- Follow your organization's data handling policies for sensitive hash data

### Container Security

- Scan container images for vulnerabilities before transferring to the air-gapped environment
- Use read-only filesystem mounts where possible
- Run containers as non-root users
- Keep container images updated with security patches (via manual transfer process)

---

## Related Guides

- [Getting Started](getting-started.md) - Initial setup and configuration
- [Agent Setup](agent-setup.md) - Configuring agents in the air-gapped environment
- [Troubleshooting](troubleshooting.md) - General troubleshooting procedures
- [Performance Optimization](optimization.md) - Tuning for air-gapped environments
