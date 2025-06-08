# Installation Guide

This guide will help you set up CipherSwarm on your system. CipherSwarm uses Docker for containerization, making it easy to deploy in various environments.

## Prerequisites

### System Requirements

- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB+ recommended
- **Storage**: 50GB+ available space
- **Network**: Stable internet connection
- **OS**: Linux, macOS, or Windows with WSL2

### Required Software

1. **Docker**

    - Docker Engine 24.0.0+
    - Docker Compose V2
    - [Docker Installation Guide](https://docs.docker.com/get-docker/)

2. **Git**

    - Git 2.0.0+
    - [Git Installation Guide](https://git-scm.com/downloads)

3. **Python** (for development only)
    - Python 3.13+
    - uv package manager
    - [Python Installation Guide](https://www.python.org/downloads/)

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/unclesp1d3r/cipherswarm.git
cd cipherswarm
```

### 2. Environment Setup

1. **Create Environment File**

```bash
cp .env.example .env
```

2. **Configure Environment Variables**

Edit `.env` with your settings:

```env
# Application
ENVIRONMENT=development
DEBUG=1
SECRET_KEY=your-secure-secret-key
ALLOWED_HOSTS=localhost,127.0.0.1

# Database
DB_USER=cipherswarm
DB_PASSWORD=your-secure-password
DB_NAME=cipherswarm
DB_HOST=db
DB_PORT=5432

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=your-secure-password

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your-secure-password
MINIO_ENDPOINT=minio:9000
MINIO_SECURE=1

# API Configuration
API_V1_STR=/api/v1
```

### 3. Development Setup

1. **Create Python Virtual Environment**

```bash
python -m venv .venv
source .venv/bin/activate  # Linux/macOS
.venv\Scripts\activate     # Windows
```

2. **Install Development Dependencies**

```bash
uv pip install -r requirements-dev.txt
```

3. **Install Pre-commit Hooks**

```bash
pre-commit install
```

### 4. Docker Setup

1. **Build Development Environment**

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml build
```

2. **Start Services**

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

3. **Initialize Database**

```bash
docker compose exec app alembic upgrade head
```

4. **Create Initial Admin User**

```bash
docker compose exec app python -m scripts.create_admin
```

### 5. Production Setup

1. **Build Production Environment**

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build
```

2. **Configure SSL**

Place your SSL certificates in `docker/nginx/certs/`:

- `server.crt`: SSL certificate
- `server.key`: Private key

3. **Start Services**

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

4. **Initialize Database**

```bash
docker compose exec app alembic upgrade head
```

## Verification

### 1. Check Services

```bash
docker compose ps
```

Expected output:

```text
NAME                COMMAND                  SERVICE             STATUS              PORTS
cipherswarm-app     "uvicorn app.main:a…"   app                running             0.0.0.0:8000->8000/tcp
cipherswarm-db      "docker-entrypoint.s…"   db                running             0.0.0.0:5432->5432/tcp
cipherswarm-minio   "minio server /data …"   minio             running             0.0.0.0:9000-9001->9000-9001/tcp
cipherswarm-redis   "redis-server --requ…"   redis             running             0.0.0.0:6379->6379/tcp
```

### 2. Access Web Interface

- Development: <http://localhost:8000>
- Production: <https://your-domain.com>

### 3. Check API Documentation

- OpenAPI UI: <http://localhost:8000/docs>
- ReDoc UI: <http://localhost:8000/redoc>

## Common Issues

### 1. Port Conflicts

If you see port conflict errors:

```bash
# Check for port usage
sudo lsof -i :8000
sudo lsof -i :5432
sudo lsof -i :6379
sudo lsof -i :9000
```

Solution: Edit `docker-compose.override.yml` to change port mappings.

### 2. Permission Issues

If you encounter permission issues:

```bash
# Fix ownership
sudo chown -R $USER:$USER .

# Fix permissions
chmod -R 755 .
chmod -R 777 storage/
```

### 3. Database Connection Issues

If the app can't connect to the database:

1. Check database logs:

```bash
docker compose logs db
```

2. Verify database is running:

```bash
docker compose exec db psql -U cipherswarm -d cipherswarm
```

### 4. MinIO Issues

If MinIO isn't accessible:

1. Check MinIO logs:

```bash
docker compose logs minio
```

2. Verify MinIO is running:

```bash
curl http://localhost:9000/minio/health/live
```

## Next Steps

After installation:

1. [Quick Start Guide](quick-start.md)
2. [Configuration Guide](configuration.md)
3. [User Guide](../user-guide/web-interface.md)
4. [Development Guide](../development/setup.md)

## Updating

To update CipherSwarm:

1. **Pull Latest Changes**

```bash
git pull origin main
```

2. **Update Dependencies**

```bash
uv pip install -r requirements.txt
```

3. **Rebuild Containers**

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml build
```

4. **Apply Database Migrations**

```bash
docker compose exec app alembic upgrade head
```

5. **Restart Services**

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

## Support

If you need help:

1. Check the [Troubleshooting Guide](../user-guide/web-interface.md)
2. Review [Common Issues](#common-issues)
3. Search [GitHub Issues](https://github.com/yourusername/cipherswarm/issues)
4. Join our [Discord Community](https://discord.gg/cipherswarm)
