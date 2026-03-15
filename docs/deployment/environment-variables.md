# Environment Variables Reference

This document provides a comprehensive reference for all environment variables used by CipherSwarm. Understanding these variables is essential for proper deployment and configuration.

## Quick Reference

| Category       | Variables                                                          | Required in Production? |
| -------------- | ------------------------------------------------------------------ | ----------------------- |
| **Critical**   | `RAILS_MASTER_KEY`, `POSTGRES_PASSWORD`, `APPLICATION_HOST`        | ✅ Yes                  |
| **Important**  | `DISABLE_SSL`, `ACTIVE_STORAGE_SERVICE`, `REDIS_URL`               | Recommended             |
| **Optional**   | `RAILS_LOG_LEVEL`, `RAILS_MAX_THREADS`, `WEB_CONCURRENCY`, `PORT`  | No                      |
| **S3 Storage** | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ENDPOINT`, etc. | Only when using S3      |

## Critical Variables - Required for Production

These variables are **required** for production deployments. The application will fail or exhibit critical failures if these are not set.

### RAILS_MASTER_KEY

**Purpose:** Decrypts Rails credentials file (`config/credentials.yml.enc`)

**Impact if Missing:** Application fails to start with error about missing credentials

**Default Value:** None

**Production Requirement:** ✅ Required

**Example:**

```bash
RAILS_MASTER_KEY=a1b2c3d4e5f6...
```

**How to Obtain:**

- Generated automatically when running `rails credentials:edit` for the first time
- Located in `config/master.key` (this file is gitignored)
- Transfer this file securely to your production system

**Security Note:** This key must be kept secret. Anyone with this key can decrypt your application's credentials.

---

### POSTGRES_PASSWORD

**Purpose:** PostgreSQL database authentication password

**Impact if Missing:** Database connection fails, application cannot start

**Default Value:** `password` (development only)

**Production Requirement:** ✅ Required

**Example:**

```bash
POSTGRES_PASSWORD=strongSecurePassword123!
```

**Usage:** Automatically used in `DATABASE_URL` construction:

```
postgres://root:${POSTGRES_PASSWORD}@postgres-db/cipherswarm
```

**Security Note:** Use a strong, randomly generated password in production. Minimum 16 characters with mixed case, numbers, and symbols.

---

### APPLICATION_HOST

**Purpose:** Sets the host for URLs in mailer templates, redirects, and Devise configuration

**Impact if Missing:**

- Email links will be broken or point to wrong host
- Password reset emails fail
- User confirmation emails fail
- Any feature that generates URLs (e.g., API callbacks) may fail

**Default Value:** `localhost` (development), `example.com` (fallback)

**Production Requirement:** ✅ Required

**Example:**

```bash
APPLICATION_HOST=cipherswarm.company.com
```

**Used In:**

- `config/environments/production.rb` (line 72): `config.action_mailer.default_url_options`
- `app/mailers/application_mailer.rb` (line 7): Email `from` address
- `config/initializers/devise.rb` (line 29): Devise mailer sender

**Common Mistakes:**

- Including `http://` or `https://` prefix (wrong: `https://example.com`, right: `example.com`)
- Using `localhost` in production
- Using IP addresses instead of hostnames for public-facing deployments

---

## Important Variables - Affects Production Behavior

These variables have sensible defaults but should be configured based on your deployment environment.

### DISABLE_SSL

**Purpose:** Controls SSL/HTTPS enforcement and redirects

**Impact if Not Set:** In production, the application will:

- Force all HTTP requests to redirect to HTTPS
- Set secure-only cookies
- Enable Strict-Transport-Security header

**Default Value:** unset. Only evaluated in production. When unset in production, SSL is enforced. Not referenced in development.

**Production Requirement:** Set to `true` only if behind a reverse proxy that handles SSL termination

**Example:**

```bash
DISABLE_SSL=true  # When behind nginx/HAProxy handling SSL
# or
# (unset)          # When Rails handles SSL directly
```

**Used In:**

- `config/environments/production.rb` (lines 36, 40): `config.assume_ssl` and `config.force_ssl`

**When to Set:**

- ✅ Set to `true`: Behind nginx, HAProxy, or cloud load balancer handling SSL
- ❌ Leave unset: Direct Internet exposure with Rails handling SSL

**Common Issues:**

- Reverse proxy redirect loops if not set correctly
- "Too many redirects" errors in browser
- Mixed content warnings

---

### ACTIVE_STORAGE_SERVICE

**Purpose:** Selects the storage backend for uploaded files (hash lists, wordlists, rules)

**Impact if Not Set:** Uses local disk storage by default

**Default Value:** `local`

**Production Requirement:** Recommended to set explicitly

**Options:**

- `local` - Local disk storage (default, works with Docker volumes)
- `s3` - S3-compatible storage (AWS S3, MinIO, SeaweedFS, etc.)

**Example:**

```bash
ACTIVE_STORAGE_SERVICE=local
# or
ACTIVE_STORAGE_SERVICE=s3
```

**Used In:**

- `config/environments/production.rb` (line 32): Storage service selection
- `config/storage.yml`: Storage backend configuration

**Dependencies:**

- When set to `s3`, requires all `AWS_*` variables (see S3 Storage Configuration section)

**Trade-offs:**

- **local**: Simpler, no external dependencies, good for single-server or Docker volume setups
- **s3**: Better for multi-server deployments, easier backups, requires external S3-compatible service

---

### REDIS_URL

**Purpose:** Redis connection string for caching, Action Cable, and Sidekiq

**Impact if Not Set:** Cache store falls back to `redis://localhost:6379/0`, Action Cable falls back to `redis://localhost:6379/1` (different Redis database). In Docker, `localhost` will not resolve to the Redis container, causing silent failures.

**Default Value:** Unset. When `REDIS_URL` is set, the same URL is used for both cache and Action Cable.

**Production Requirement:** Recommended to set when using non-default Redis configuration

**Example:**

```bash
REDIS_URL=redis://redis-db:6379/0
# or with authentication
REDIS_URL=redis://:password@redis-host:6379/0
# or with TLS
REDIS_URL=rediss://redis-host:6379/0
```

**Used In:**

- `config/environments/production.rb` (line 60): Cache store configuration
- `config/cable.yml`: Action Cable adapter (production)
- Sidekiq configuration (implicit)

**Common Mistakes:**

- Using `localhost` in Docker environments (should be service name like `redis-db`)
- Forgetting to include database number (e.g., `/0`)
- Not enabling authentication in production Redis instances

---

## Optional Variables - Performance Tuning

These variables have sensible defaults and are only needed for specific tuning or customization.

### RAILS_LOG_LEVEL

**Purpose:** Controls log verbosity

**Impact if Not Set:** Uses `info` level by default

**Default Value:** `info`

**Options:** `debug`, `info`, `warn`, `error`, `fatal`

**Example:**

```bash
RAILS_LOG_LEVEL=warn  # Less verbose
RAILS_LOG_LEVEL=debug # Very verbose, includes SQL queries
```

**Used In:**

- `config/environments/production.rb` (line 50): Log level configuration

**When to Change:**

- **debug**: Troubleshooting production issues (temporary), includes SQL queries and detailed traces
- **warn** or **error**: High-traffic production to reduce log volume
- **info** (default): Balanced for normal production use

**Performance Note:** `debug` level logs can significantly increase disk I/O and volume size.

---

### RAILS_MAX_THREADS

**Purpose:** Sets Puma thread pool size (per worker process)

**Impact if Not Set:** Uses 3 threads per worker

**Default Value:** `3`

**Example:**

```bash
RAILS_MAX_THREADS=5
```

**Used In:**

- `config/puma.rb` (line 29): Thread pool configuration
- Database connection pool sizing (should match or exceed thread count)

**Tuning Guidance:**

- **Low thread count (1-3)**: Simple apps, low concurrency needs
- **Medium thread count (5-10)**: Balanced throughput and latency
- **High thread count (10+)**: I/O-bound apps, may hit diminishing returns due to GVL

**Important:** Ensure database connection pool (`config/database.yml` pool setting) is at least equal to `RAILS_MAX_THREADS` (per process). Total DB connections across all workers = `RAILS_MAX_THREADS` × `WEB_CONCURRENCY`.

---

### WEB_CONCURRENCY

**Purpose:** Number of Puma worker processes (multi-process for CPU utilization)

**Impact if Not Set:** Runs in single-process mode (no forking)

**Default Value:** `0` (single-process mode, no forking). Set to 2+ for multi-process mode.

**Example:**

```bash
WEB_CONCURRENCY=4  # 4 worker processes
```

**Used In:**

- `config/puma.rb` (line 10 comment): Worker process configuration

**Tuning Guidance:**

- **0 (default)**: Single-process mode, development, small deployments
- **2-4 workers**: Standard production (1-2 per CPU core)
- **4+ workers**: High-traffic production

**Scaling Formula:**

- For `n` active cracking agents, consider `n + 1` web replicas with load balancing (see [Production Load Balancing](production-load-balancing.md))

**Memory Consideration:** Each worker consumes ~200-300MB RAM. Monitor memory usage when increasing worker count.

---

### PORT

**Purpose:** Application listen port

**Impact if Not Set:** Uses port 3000

**Default Value:** `3000`

**Example:**

```bash
PORT=8080
```

**Used In:**

- `config/puma.rb` (line 33): Port binding configuration

**When to Change:**

- Port 3000 conflicts with another service
- Corporate firewall requires specific port
- Running multiple Rails apps on same host

**Docker Note:** In Docker, this is the *internal* container port. Map to host port via `ports:` in `docker-compose.yml`.

---

### SOLID_QUEUE_IN_PUMA

**Purpose:** Runs Solid Queue background job processor inside Puma (single-server deployments)

**Impact if Not Set:** Background jobs must be processed by separate Sidekiq process

**Default Value:** unset (disabled)

**Example:**

```bash
SOLID_QUEUE_IN_PUMA=true
```

**Used In:**

- `config/puma.rb` (line 39): Solid Queue plugin activation

**When to Use:**

- ✅ Single-server deployments where running separate Sidekiq is inconvenient
- ✅ Development/testing environments
- ❌ Production multi-server deployments (use dedicated Sidekiq workers instead)

**Note:** CipherSwarm uses Sidekiq, not Solid Queue. This variable exists in Puma's default config but has no effect in this application.

---

### PIDFILE

**Purpose:** Specifies Puma PID file location

**Impact if Not Set:** No PID file is created

**Default Value:** unset (no PID file created)

**Example:**

```bash
PIDFILE=/var/run/puma.pid
```

**Used In:**

- `config/puma.rb` (line 43): PID file configuration

**When to Set:**

- Process monitoring tools require specific PID file location
- Running multiple Puma instances on same host
- System service management (systemd, init.d)

---

## S3 Storage Configuration

These variables are **only required** when `ACTIVE_STORAGE_SERVICE=s3`. The application will fail at startup if S3 is enabled but credentials are missing.

### AWS_ACCESS_KEY_ID

**Purpose:** S3 access key

**Impact if Missing (when S3 enabled):** Application fails at startup with error about missing credentials

**Default Value:** None

**Production Requirement:** ✅ Required when using S3

**Example:**

```bash
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
```

**Used In:**

- `config/storage.yml` (line 14): S3 service configuration
- `config/initializers/storage_config_check.rb`: Startup validation

**S3-Compatible Services:**

- AWS S3: Use IAM access key
- MinIO: Use `MINIO_ROOT_USER`
- SeaweedFS: Use S3 gateway access key

---

### AWS_SECRET_ACCESS_KEY

**Purpose:** S3 secret key

**Impact if Missing (when S3 enabled):** Application fails at startup with error about missing credentials

**Default Value:** None

**Production Requirement:** ✅ Required when using S3

**Example:**

```bash
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

**Used In:**

- `config/storage.yml` (line 15): S3 service configuration
- `config/initializers/storage_config_check.rb`: Startup validation

**Security Note:** This is a secret credential. Never commit to version control or logs.

---

### AWS_ENDPOINT

**Purpose:** S3 endpoint URL (for non-AWS S3-compatible services)

**Impact if Missing:** Defaults to AWS S3 endpoints, fails for MinIO/SeaweedFS

**Default Value:** None (uses AWS S3 endpoints)

**Production Requirement:** ✅ Required for MinIO, SeaweedFS, or other S3-compatible services

**Example:**

```bash
AWS_ENDPOINT=http://minio:9000          # MinIO
AWS_ENDPOINT=http://seaweedfs:8333      # SeaweedFS S3 gateway
AWS_ENDPOINT=https://s3.custom.com      # Custom S3-compatible service
```

**Used In:**

- `config/storage.yml` (line 17): S3 endpoint configuration

**Important for Air-Gapped Deployments:** Must point to internal S3-compatible service.

---

### AWS_BUCKET

**Purpose:** S3 bucket name

**Impact if Not Set:** Uses default bucket name `application`

**Default Value:** `application`

**Example:**

```bash
AWS_BUCKET=cipherswarm-storage
```

**Used In:**

- `config/storage.yml` (line 13): Bucket configuration

**Prerequisites:** Bucket must exist before application starts. Create manually via:

- AWS CLI: `aws s3 mb s3://bucket-name`
- MinIO CLI: `mc mb local/bucket-name`
- SeaweedFS S3: Auto-created on first PUT

---

### AWS_REGION

**Purpose:** AWS region (or placeholder for S3-compatible services)

**Impact if Not Set:** Uses default region `us-east-1`

**Default Value:** `us-east-1`

**Example:**

```bash
AWS_REGION=us-west-2      # AWS S3
AWS_REGION=us-east-1      # MinIO (placeholder, not used)
```

**Used In:**

- `config/storage.yml` (line 16): Region configuration

**Note:** MinIO and SeaweedFS ignore this setting but may require it to be set to avoid SDK errors.

---

### AWS_FORCE_PATH_STYLE

**Purpose:** Use path-style URLs instead of virtual-hosted-style URLs

**Impact if Not Set:** Uses virtual-hosted-style URLs (e.g., `bucket.s3.amazonaws.com`), which fails for MinIO

**Default Value:** `false`

**Production Requirement:** ✅ Required for MinIO (set to `true`)

**Example:**

```bash
AWS_FORCE_PATH_STYLE=true   # Required for MinIO
```

**Used In:**

- `config/storage.yml` (line 18): Force path style configuration

**URL Style Comparison:**

- Virtual-hosted: `http://bucket.s3.amazonaws.com/key` (AWS S3 default)
- Path-style: `http://s3.amazonaws.com/bucket/key` (required for MinIO)

---

## Validation and Error Handling

CipherSwarm includes built-in validation for critical environment variables:

### Startup Validation

**S3 Credentials Check** (`config/initializers/storage_config_check.rb`):

- Validates `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` when `ACTIVE_STORAGE_SERVICE=s3`
- **Fails fast at startup** with clear error message if credentials are missing

**Example Error:**

```
S3 storage is active (ACTIVE_STORAGE_SERVICE=s3) but required credentials are missing:
  AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
Set these environment variables or switch to local storage (ACTIVE_STORAGE_SERVICE=local).
```

### Future Enhancements

The following validations are planned (see issue for tracking):

- `APPLICATION_HOST` validation in production (fails fast if missing)
- `RAILS_MASTER_KEY` validation (currently handled by Rails itself)
- Clear error messages for missing `POSTGRES_PASSWORD` with connection details

---

## Common Configuration Scenarios

### Scenario 1: Single-Server Docker Deployment (Local Storage)

**Minimal Production Configuration:**

```bash
# Required
RAILS_MASTER_KEY=<from-config/master.key>
POSTGRES_PASSWORD=strongSecurePassword123!
APPLICATION_HOST=cipherswarm.company.com

# Recommended
DISABLE_SSL=true  # nginx handles SSL
ACTIVE_STORAGE_SERVICE=local
REDIS_URL=redis://redis-db:6379/0
```

**Use Case:** Small deployments, lab environments, single server behind nginx

---

### Scenario 2: Multi-Server Docker Deployment (S3 Storage)

**Full Production Configuration:**

```bash
# Required
RAILS_MASTER_KEY=<from-config/master.key>
POSTGRES_PASSWORD=strongSecurePassword123!
APPLICATION_HOST=cipherswarm.company.com

# Important
DISABLE_SSL=true  # nginx handles SSL
ACTIVE_STORAGE_SERVICE=s3
REDIS_URL=redis://redis-db:6379/0

# S3 Storage
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=minioadmin
AWS_BUCKET=cipherswarm
AWS_ENDPOINT=http://minio:9000
AWS_FORCE_PATH_STYLE=true
AWS_REGION=us-east-1

# Performance Tuning
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=4
```

**Use Case:** Production deployments with multiple web replicas and centralized storage

---

### Scenario 3: Air-Gapped Deployment (Local Storage)

**Air-Gapped Configuration:**

```bash
# Required
RAILS_MASTER_KEY=<from-config/master.key>
POSTGRES_PASSWORD=strongSecurePassword123!
APPLICATION_HOST=cipherswarm.local

# Important
DISABLE_SSL=true  # Internal network only
ACTIVE_STORAGE_SERVICE=local
REDIS_URL=redis://redis-db:6379/0

# Optional
RAILS_LOG_LEVEL=info
```

**Use Case:** Isolated lab environments, no external Internet access

See [Air-Gapped Deployment Guide](air-gapped-deployment.md) for complete instructions.

---

### Scenario 4: Development Environment

**Development Configuration:**

```bash
# Minimal for development (most have defaults)
POSTGRES_PASSWORD=password
APPLICATION_HOST=localhost

# Optional overrides
RAILS_LOG_LEVEL=debug
PORT=3000
```

**Use Case:** Local development, testing, debugging

---

## Environment Variable Loading

CipherSwarm uses standard Rails environment variable loading:

1. **System environment variables** (highest priority)
2. **`.env` file** in project root (via Docker Compose `env_file` or manual loading)
3. **Default values** in configuration files (lowest priority)

### Docker Compose Integration

The `docker-compose.yml` file uses anchors to share common environment variables:

```yaml
x-common-env-vars:
  RAILS_MASTER_KEY: ${RAILS_MASTER_KEY}
  REDIS_URL: redis://redis-db:6379
  DATABASE_URL: 
    postgres://root:${POSTGRES_PASSWORD:-password}@postgres-db/cipherswarm
  APPLICATION_HOST: ${APPLICATION_HOST:-localhost}
  DISABLE_SSL: ${DISABLE_SSL:-true}
  ACTIVE_STORAGE_SERVICE: ${ACTIVE_STORAGE_SERVICE:-local}
```

**Best Practice:** Create a `.env` file in the project root with your configuration:

```bash
# .env
RAILS_MASTER_KEY=a1b2c3d4e5f6...
POSTGRES_PASSWORD=strongPassword
APPLICATION_HOST=cipherswarm.company.com
ACTIVE_STORAGE_SERVICE=local
```

Docker Compose will automatically load this file.

---

## Security Best Practices

1. **Never commit `.env` to version control** - Already in `.gitignore`
2. **Use strong passwords** - Minimum 16 characters for `POSTGRES_PASSWORD`
3. **Rotate credentials regularly** - Especially `RAILS_MASTER_KEY` and database passwords
4. **Restrict access to credentials** - File permissions 600 for `.env` and `config/master.key`
5. **Use secrets management in production** - Consider HashiCorp Vault, AWS Secrets Manager, or similar
6. **Enable Redis authentication** - Use password in `REDIS_URL` for production
7. **Use TLS for Redis** - Use `rediss://` protocol for encrypted connections

---

## Troubleshooting

### Application Fails to Start

**Symptom:** Application exits immediately after startup

**Possible Causes:**

- Missing `RAILS_MASTER_KEY`: Check `config/master.key` exists and `RAILS_MASTER_KEY` is set
- Database connection failure: Verify `POSTGRES_PASSWORD` and database is running
- Missing S3 credentials: When `ACTIVE_STORAGE_SERVICE=s3`, ensure all `AWS_*` variables are set

**Debug Steps:**

```bash
# Check environment variables are loaded
docker compose exec web env | grep -E "RAILS_MASTER_KEY|POSTGRES_PASSWORD|APPLICATION_HOST"

# Check Rails can decrypt credentials
docker compose exec web bin/rails runner "puts Rails.application.credentials.config"

# Check database connection
docker compose exec web bin/rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').to_a"
```

---

### Emails Not Sending / Broken Links

**Symptom:** Password reset emails have broken links, or emails fail to send

**Cause:** Missing or incorrect `APPLICATION_HOST`

**Fix:**

```bash
# Set APPLICATION_HOST to your domain (no http:// prefix)
APPLICATION_HOST=cipherswarm.company.com
```

**Verify:**

```bash
# Check mailer configuration
docker compose exec web bin/rails runner "puts ActionMailer::Base.default_url_options"
# Should output: {:host=>"cipherswarm.company.com"}
```

---

### "Too Many Redirects" Error

**Symptom:** Browser shows "too many redirects" or redirect loop

**Cause:** `DISABLE_SSL` not set when behind reverse proxy handling SSL

**Fix:**

```bash
# When nginx/HAProxy handles SSL termination
DISABLE_SSL=true
```

**Verify nginx configuration includes:**

```nginx
proxy_set_header X-Forwarded-Proto $scheme;
```

---

### Storage Upload Failures

**Symptom:** File uploads fail or return 500 errors

**Cause:**

- Incorrect `ACTIVE_STORAGE_SERVICE` setting
- Missing or incorrect S3 credentials
- S3 bucket doesn't exist
- Wrong `AWS_ENDPOINT` for S3-compatible service

**Debug Steps:**

```bash
# Check storage service configuration
docker compose exec web bin/rails runner "puts Rails.application.config.active_storage.service"

# Test S3 connection (when using S3)
docker compose exec web bin/rails runner "ActiveStorage::Blob.service.exist?('test')"

# Check S3 bucket exists (MinIO example)
docker compose exec minio mc ls local/
```

---

## Reference: Configuration Files

Environment variables are referenced in the following files:

| File                                          | Purpose                       | Variables Used                                                                                                   |
| --------------------------------------------- | ----------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `config/environments/production.rb`           | Production environment config | `ACTIVE_STORAGE_SERVICE`, `DISABLE_SSL`, `RAILS_LOG_LEVEL`, `APPLICATION_HOST`, `REDIS_URL`                      |
| `config/storage.yml`                          | Storage backend configuration | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_BUCKET`, `AWS_REGION`, `AWS_ENDPOINT`, `AWS_FORCE_PATH_STYLE` |
| `config/puma.rb`                              | Puma web server configuration | `RAILS_MAX_THREADS`, `PORT`, `SOLID_QUEUE_IN_PUMA`, `PIDFILE`                                                    |
| `app/mailers/application_mailer.rb`           | Mailer base class             | `APPLICATION_HOST`                                                                                               |
| `config/initializers/devise.rb`               | Devise authentication         | `APPLICATION_HOST`                                                                                               |
| `config/initializers/storage_config_check.rb` | S3 credentials validation     | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`                                                                     |
| `docker-compose.yml`                          | Docker Compose orchestration  | `RAILS_MASTER_KEY`, `POSTGRES_PASSWORD`, `APPLICATION_HOST`, `DISABLE_SSL`, `ACTIVE_STORAGE_SERVICE`             |

---

## Additional Resources

- [Air-Gapped Deployment Guide](air-gapped-deployment.md) - Deploying in isolated environments
- [Production Load Balancing](production-load-balancing.md) - Multi-server deployment with nginx
- [Storage Backend Documentation](../../config/storage.yml) - Storage configuration details
- [Rails Configuration Guide](https://guides.rubyonrails.org/configuring.html) - Rails configuration reference
