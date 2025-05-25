# Configuration Guide

This guide covers the configuration options available in CipherSwarm and how to customize them for your environment.

## Environment Configuration

CipherSwarm uses environment variables for configuration. These can be set in the `.env` file or through your system's environment.

### Core Settings

```env
# Application
ENVIRONMENT=development  # development, staging, production
DEBUG=1  # 0 for production
SECRET_KEY=your-secure-secret-key
ALLOWED_HOSTS=localhost,127.0.0.1

# API Configuration
API_V1_STR=/api/v1
PROJECT_NAME=CipherSwarm
VERSION=0.1.0
```

### Database Configuration

```env
# PostgreSQL
DB_USER=cipherswarm
DB_PASSWORD=your-secure-password
DB_NAME=cipherswarm
DB_HOST=db
DB_PORT=5432
DB_POOL_SIZE=20
DB_POOL_OVERFLOW=10
DB_TIMEOUT=30

# Connection string format
DATABASE_URL=postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
```

### Redis Configuration

```env
# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=your-secure-password
REDIS_DB=0
REDIS_TIMEOUT=30

# Connection string format
REDIS_URL=redis://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}/${REDIS_DB}
```

### MinIO Configuration

```env
# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your-secure-password
MINIO_ENDPOINT=minio:9000
MINIO_REGION=us-east-1
MINIO_SECURE=1
MINIO_BUCKET_NAME=cipherswarm

# Optional: External MinIO
MINIO_EXTERNAL_ENDPOINT=minio.example.com
MINIO_ACCESS_KEY=${MINIO_ROOT_USER}
MINIO_SECRET_KEY=${MINIO_ROOT_PASSWORD}
```

### Security Settings

```env
# Authentication
AUTH_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7
PASSWORD_RESET_TOKEN_EXPIRE_HOURS=24
VERIFY_TOKEN_EXPIRE_HOURS=48

# Security Headers
SECURITY_CSRF_COOKIE=1
SECURITY_CSRF_HEADER=X-CSRF-Token
SECURITY_HSTS_SECONDS=31536000
SECURITY_FRAME_DENY=1

# Rate Limiting
RATE_LIMIT_DEFAULT=100/minute
RATE_LIMIT_AUTH=20/minute
RATE_LIMIT_AGENTS=200/minute
```

### Agent Configuration

```env
# Agent Settings
AGENT_HEARTBEAT_INTERVAL=30
AGENT_TIMEOUT_SECONDS=90
AGENT_MAX_TASKS=5
AGENT_RESOURCE_PATH=/data/resources
AGENT_RESULT_PATH=/data/results

# Task Distribution
TASK_CHUNK_SIZE=1000000
TASK_MAX_RUNTIME_HOURS=72
TASK_RETRY_LIMIT=3
```

### Logging Configuration

```env
# Logging
LOG_LEVEL=INFO  # DEBUG, INFO, WARNING, ERROR, CRITICAL
LOG_FORMAT=json  # json, text
LOG_PATH=/var/log/cipherswarm
LOG_MAX_SIZE=100MB
LOG_BACKUP_COUNT=10
LOG_MAIL_ADMINS=0
```

## Docker Configuration

### Development Environment

```yaml
# docker-compose.dev.yml
version: "3.8"
services:
    app:
        build:
            context: .
            dockerfile: docker/app/Dockerfile.dev
        volumes:
            - .:/app
        environment:
            - ENVIRONMENT=development
            - DEBUG=1
        ports:
            - "8000:8000"
        depends_on:
            - db
            - redis
            - minio

    db:
        image: postgres:16-alpine
        environment:
            - POSTGRES_USER=cipherswarm
            - POSTGRES_PASSWORD=development
            - POSTGRES_DB=cipherswarm_dev
        volumes:
            - postgres_data:/var/lib/postgresql/data
        ports:
            - "5432:5432"

    redis:
        image: redis:alpine
        command: redis-server --requirepass development
        ports:
            - "6379:6379"
        volumes:
            - redis_data:/data

    minio:
        image: minio/minio
        ports:
            - "9000:9000"
            - "9001:9001"
        volumes:
            - minio_data:/data
        environment:
            - MINIO_ROOT_USER=minioadmin
            - MINIO_ROOT_PASSWORD=minioadmin
        command: server /data --console-address ":9001"

volumes:
    postgres_data:
    redis_data:
    minio_data:
```

### Production Environment

```yaml
# docker-compose.prod.yml
version: "3.8"
services:
    nginx:
        build:
            context: ./docker/nginx
            dockerfile: Dockerfile
        ports:
            - "80:80"
            - "443:443"
        volumes:
            - ./static:/usr/share/nginx/html/static
            - ./certs:/etc/nginx/certs
        depends_on:
            - app

    app:
        build:
            context: .
            dockerfile: docker/app/Dockerfile.prod
        environment:
            - ENVIRONMENT=production
            - DEBUG=0
        depends_on:
            - db
            - redis
            - minio

    db:
        image: postgres:16-alpine
        environment:
            - POSTGRES_USER=${DB_USER}
            - POSTGRES_PASSWORD=${DB_PASSWORD}
            - POSTGRES_DB=${DB_NAME}
        volumes:
            - postgres_data:/var/lib/postgresql/data
            - ./backup:/backup
        command: postgres -c config_file=/etc/postgresql/postgresql.conf

    redis:
        image: redis:alpine
        command: redis-server --requirepass ${REDIS_PASSWORD}
        volumes:
            - redis_data:/data

    minio:
        image: minio/minio
        volumes:
            - minio_data:/data
        environment:
            - MINIO_ROOT_USER=${MINIO_ACCESS_KEY}
            - MINIO_ROOT_PASSWORD=${MINIO_SECRET_KEY}
        command: server /data --console-address ":9001"

volumes:
    postgres_data:
    redis_data:
    minio_data:
```

## Application Configuration

### FastAPI Settings

```python
# app/core/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "CipherSwarm"
    VERSION: str = "0.1.0"
    API_V1_STR: str = "/api/v1"

    # Database
    DATABASE_URL: str
    DB_POOL_SIZE: int = 20
    DB_POOL_OVERFLOW: int = 10
    DB_TIMEOUT: int = 30

    # Redis
    REDIS_URL: str
    REDIS_TIMEOUT: int = 30

    # MinIO
    MINIO_ENDPOINT: str
    MINIO_ACCESS_KEY: str
    MINIO_SECRET_KEY: str
    MINIO_SECURE: bool = True
    MINIO_BUCKET_NAME: str = "cipherswarm"

    # Security
    SECRET_KEY: str
    AUTH_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Agent
    AGENT_HEARTBEAT_INTERVAL: int = 30
    AGENT_TIMEOUT_SECONDS: int = 90
    AGENT_MAX_TASKS: int = 5

    model_config = ConfigDict(env_file=".env")
```

### Logging Configuration

```python
# app/core/logging.py
import logging.config

LOGGING_CONFIG = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "json": {
            "()": "pythonjsonlogger.jsonlogger.JsonFormatter",
            "fmt": "%(levelname)s %(asctime)s %(name)s %(message)s"
        },
        "standard": {
            "format": "%(asctime)s [%(levelname)s] %(name)s: %(message)s"
        }
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "standard",
            "stream": "ext://sys.stdout"
        },
        "file": {
            "class": "logging.handlers.RotatingFileHandler",
            "formatter": "json",
            "filename": "/var/log/cipherswarm/app.log",
            "maxBytes": 10485760,
            "backupCount": 10
        }
    },
    "loggers": {
        "": {
            "handlers": ["console", "file"],
            "level": "INFO"
        }
    }
}
```

## Security Configuration

### CORS Settings

```python
# app/core/security.py
from fastapi.middleware.cors import CORSMiddleware

origins = [
    "http://localhost",
    "http://localhost:8000",
    "https://your-domain.com"
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)
```

### Authentication Settings

```python
# app/core/auth.py
from datetime import timedelta, UTC, datetime
from jose import jwt

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7

def create_access_token(data: dict):
    expire = datetime.now(UTC) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = data.copy()
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
```

## Resource Configuration

### MinIO Bucket Setup

```python
# app/core/storage.py
from minio import Minio

client = Minio(
    endpoint=MINIO_ENDPOINT,
    access_key=MINIO_ACCESS_KEY,
    secret_key=MINIO_SECRET_KEY,
    secure=MINIO_SECURE
)

# Ensure required buckets exist
REQUIRED_BUCKETS = [
    "wordlists",
    "rules",
    "masks",
    "results"
]

for bucket in REQUIRED_BUCKETS:
    if not client.bucket_exists(bucket):
        client.make_bucket(bucket)
```

## Performance Tuning

### Database Optimization

```python
# app/db/session.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

engine = create_engine(
    DATABASE_URL,
    pool_size=DB_POOL_SIZE,
    max_overflow=DB_POOL_OVERFLOW,
    pool_timeout=DB_TIMEOUT,
    pool_pre_ping=True
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)
```

### Redis Optimization

```python
# app/core/cache.py
from redis import Redis

redis = Redis.from_url(
    REDIS_URL,
    socket_timeout=REDIS_TIMEOUT,
    socket_connect_timeout=REDIS_TIMEOUT,
    retry_on_timeout=True
)
```

## Monitoring Configuration

### Health Checks

```python
# app/api/v1/endpoints/health.py
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

router = APIRouter()

@router.get("/health")
def health_check(db: Session = Depends(get_db)):
    checks = {
        "database": check_database(db),
        "redis": check_redis(),
        "minio": check_minio(),
        "disk": check_disk_space()
    }
    return checks
```

### Metrics Collection

```python
# app/core/metrics.py
from prometheus_client import Counter, Histogram

REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency',
    ['method', 'endpoint']
)
```

## Next Steps

After configuring CipherSwarm:

1. [Quick Start Guide](quick-start.md)
2. [User Guide](../user-guide/web-interface.md)
3. [Development Guide](../development/setup.md)
4. [Production Deployment](../deployment/production.md)
