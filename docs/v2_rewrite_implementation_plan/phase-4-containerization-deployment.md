# Phase 4: Containerization and Deployment

This document outlines the implementation plan for containerizing CipherSwarm and deploying the full stack using Docker and Docker Compose, following CipherSwarm's Docker standards and [Rails Deployment Guide](https://guides.rubyonrails.org/deployment.html).

---

## Table of Contents

<!-- mdformat-toc start --slug=github --no-anchors --maxlevel=2 --minlevel=1 -->

- [Phase 4: Containerization and Deployment](#phase-4-containerization-and-deployment)
  - [Table of Contents](#table-of-contents)
  - [Context](#context)
  - [Implementation Checklist](#implementation-checklist)
  - [References](#references)

<!-- mdformat-toc end -->

---

## Context

- **Goal:** Enable reproducible, secure, and efficient deployment of CipherSwarm using containers.
- **Scope:** Rails app, PostgreSQL, ActiveStorage (S3-compatible), and Thruster (for production), with optional Redis for caching, with development and production configurations.
- **Critical Standards (from CipherSwarm Docker Guidelines):**
  - **Rails Application:**
    - Ruby 3.4.5 base image
    - Use Bundler for dependency management
    - Health checks and graceful shutdown
    - Non-root user in container
    - Hot reload for development
  - **PostgreSQL Database:**
    - Version 17 or later
    - Persistent volume mounts
    - Automated backups
  - **Redis Cache (Optional):**
    - Latest stable version
    - Production caching backend (Solid Cache)
    - Sidekiq task queue backend
    - Development uses in-memory caching
  - **ActiveStorage Backend:**
    - S3-compatible storage (MinIO or similar)
    - Configured buckets for attack resources
    - TLS/SSL support
    - Access key management
  - **Thruster Reverse Proxy (production):**
    - HTTP/2 support
    - SSL termination
    - Static asset serving
    - X-Sendfile support
  - **Security:**
    - All containers run as non-root
    - Read-only root filesystem where possible
    - Resource limits and quotas
    - Secrets managed via Rails credentials and environment files (never in images)
  - **Deployment:**
    - Single-command deployment: `docker compose up -d`
    - Automated DB migrations
    - Health check monitoring
    - Backup and restore procedures
    - Log aggregation and monitoring
    - Zero-downtime updates and rollback
  - **Development Workflow:**
    - Hot reload for development
    - Shared volume mounts for code changes
    - Test environment configuration
    - Debug capabilities
  - **CI/CD Integration:**
    - Automated builds and container testing
    - Security scanning
    - Registry pushes and deployment automation
  - **Backup Strategy:**
    - Database dumps
    - ActiveStorage bucket backups
    - Automated scheduling and retention
  - **Scaling:**
    - Service replication
    - Load balancing
    - Storage expansion
- **Docker Compose Swarm Compatibility:**
  - The `docker-compose.yml` file should be written to support both standard Compose and Docker Swarm stack deployments where feasible. This enables scaling and orchestration via `docker stack deploy` as described in [this article](https://towardsaws.com/deploying-a-docker-stack-across-a-docker-swarm-using-a-docker-compose-file-ddac4c0253da).
  - Use Compose file version 3+, avoid `build` in production, and consider `deploy` keys for Swarm compatibility.
- **Automated Dockerfile Build/Run Testing:**
  - All Dockerfiles (dev and prod) must be automatically built and run-tested as part of CI and the `just ci-check` workflow. This ensures that any changes to Dockerfiles are validated for build success and basic runtime health, preventing broken images from reaching production or development environments.

---

## Implementation Checklist

### 1. Rails Application Dockerfile

- [ ] Create `docker/app/Dockerfile.dev` for development
- [ ] Create `docker/app/Dockerfile.prod` for production
- [ ] Use Ruby 3.4.5 base image
- [ ] Install dependencies with Bundler
- [ ] Configure for hot reload in dev
- [ ] Add healthcheck endpoint
- [ ] Run as non-root user
- [ ] Set up graceful shutdown

### 2. Docker Compose Configuration

- [ ] Create `docker-compose.dev.yml` for local development
- [ ] Create `docker-compose.prod.yml` for production
- [ ] Define services: app, db (Postgres 17+), storage backend (S3-compatible), thruster (prod only), redis (optional), sidekiq
- [ ] Configure persistent volumes for db, storage, redis (if used)
- [ ] Set up environment variables and Rails credentials
- [ ] Add healthcheck and restart policies
- [ ] Mount static assets and certs for thruster
- [ ] Document usage in README
- [ ] **Endeavor to ensure docker-compose.yml is compatible with Docker Swarm stack deployments** ([see article](https://towardsaws.com/deploying-a-docker-stack-across-a-docker-swarm-using-a-docker-compose-file-ddac4c0253da))

### 3. Database and Resource Management

- [ ] Ensure Postgres uses persistent storage
- [ ] Configure ActiveStorage backend for resources
- [ ] Add backup/restore hooks for db and storage
- [ ] Set up Redis for caching (optional) and Sidekiq task queue

### 4. Security and Best Practices

- [ ] Run all containers as non-root
- [ ] Set resource limits/quotas in compose files
- [ ] Use read-only root filesystem where possible
- [ ] Store secrets in Rails credentials and env files, not in images
- [ ] Enable TLS/SSL for ActiveStorage backend and Thruster (prod)

### 5. CI/CD Workflow Updates

- [ ] Update `.github/workflows/ci.yml` to build and test Docker images
- [ ] Add `.github/workflows/docker-deploy.yml` for deployment
- [ ] Ensure `just ci-check` runs in containerized environment
- [ ] Automate DB migrations on deploy
- [ ] Add security scanning for images
- [ ] Document CI/CD process
- [ ] **Add automated build and run-test for all Dockerfiles (dev and prod) in CI and justfile**

### 6. Validation and Testing

- [ ] Test local dev stack with `docker compose up`
- [ ] Test production stack with sample data
- [ ] Validate health checks and graceful shutdown
- [ ] Run integration tests in containers
- [ ] Verify backup/restore procedures
- [ ] **Verify Dockerfile build/run tests pass in CI and just ci-check**

---

## References

- [Rails Deployment Guide](https://guides.rubyonrails.org/deployment.html)
- [Dockerizing Rails Applications](https://www.docker.com/blog/dockerizing-rails-applications/)
- [Kamal Deployment Tool](https://kamal-deploy.org/)
- [Deploying a Docker Stack Across a Docker Swarm Using a Docker Compose File](https://towardsaws.com/deploying-a-docker-stack-across-a-docker-swarm-using-a-docker-compose-file-ddac4c0253da)
- [Docker Documentation](https://docs.docker.com)
- [Docker Compose Documentation](https://docs.docker.com/compose)
