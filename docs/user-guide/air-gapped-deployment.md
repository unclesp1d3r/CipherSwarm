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
- Network connectivity between CipherSwarm server components (internal only)
- Network connectivity between agents and the CipherSwarm server (internal only)

### Required Container Images

Transfer the following images to the air-gapped environment:

- CipherSwarm application image
- PostgreSQL image
- Redis image
- MinIO image
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
docker pull minio/minio:latest

docker save cipherswarm:latest postgres:16 redis:7 minio/minio:latest \
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
4. Alternatively, mount resource directories directly into the MinIO container

---

## Deployment Steps

### Step 1: Transfer Container Images

Transfer all required container images to the air-gapped environment using one of the methods described in [Prerequisites](#image-transfer-methods).

### Step 2: Configure Docker Compose

Ensure the `docker-compose.yml` file does not reference any external registries or services:

```yaml
services:
  web:
    image: cipherswarm:latest  # Use local image, not registry URL
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=<generate-a-secure-key>
      - DATABASE_URL=postgres://cipherswarm:<secure-password>@postgres-db:5432/cipherswarm
      - REDIS_URL=redis://redis:6379/0
      - MINIO_ENDPOINT=http://minio:9000
      - MINIO_ACCESS_KEY=<minio-access-key>
      - MINIO_SECRET_KEY=<minio-secret-key>
    depends_on:
      - postgres-db
      - redis
      - minio

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

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: <minio-access-key>
      MINIO_ROOT_PASSWORD: <minio-secret-key>
    volumes:
      - minio_data:/data

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

volumes:
  postgres_data:
  redis_data:
  minio_data:
```

### Step 3: Verify Asset Precompilation

Before starting the application, verify that all assets are bundled in the container:

```bash
# Check that assets are precompiled in the container
docker run --rm cipherswarm:latest ls public/assets/

# Verify CSS files exist
docker run --rm cipherswarm:latest ls public/assets/*.css

# Verify JavaScript files exist
docker run --rm cipherswarm:latest ls public/assets/*.js
```

### Step 4: Start the Stack

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

### Step 5: Verify the Deployment

1. Access the web interface at `http://<server-ip>:3000`
2. Log in with the default admin credentials (from seed data)
3. Check the system health dashboard for all green statuses
4. Register an agent and verify connectivity

### Step 6: Bundle Documentation (Optional)

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

  Verify that the system health dashboard reports correct status for all services (PostgreSQL, Redis, MinIO, Application) within the isolated network.

- [ ] **8. Agent API accessible from isolated agents**

  From an agent within the air-gapped network, verify that the agent API endpoints respond correctly:

  - Authentication: `GET /api/v1/client/authenticate`
  - Configuration: `GET /api/v1/client/configuration`
  - Task assignment: `GET /api/v1/client/tasks/new`

- [ ] **9. File uploads/downloads work with MinIO (no S3 external calls)**

  Upload a test wordlist through the web interface and verify it is stored in the local MinIO instance. Download it from an agent to verify the full round-trip.

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
5. From an agent, verify the resource can be downloaded:

```bash
# Check that MinIO is serving files
curl -s http://<server-ip>:9000/minio/health/ready
```

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
   docker compose exec web ping minio
   ```

2. Check that service names in configuration match `docker-compose.yml` service names

3. Verify no firewall rules block inter-container communication

4. Check Docker DNS resolution:

   ```bash
   docker compose exec web nslookup postgres-db
   ```

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

#### MinIO Backup

```bash
# Backup MinIO data
docker compose exec minio \
  mc mirror /data /backup/minio_$(date +%Y%m%d)

# Or backup the Docker volume
docker run --rm \
  -v cipherswarm_minio_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/minio_backup.tar.gz /data
```

#### Full System Backup

```bash
# Stop services for consistent backup
docker compose stop

# Backup all volumes
for vol in postgres_data redis_data minio_data; do
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
3. Or copy files directly to the MinIO data directory
4. Verify resources are accessible from agents

---

## Security Considerations

### Network Isolation

- Ensure the air-gapped network is truly isolated (no bridged connections)
- Use separate VLANs for CipherSwarm server components and agents
- Restrict inter-node communication to required ports only
- Monitor for unauthorized network connections

### Access Controls

- Use strong passwords for all services (PostgreSQL, Redis, MinIO, admin accounts)
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
