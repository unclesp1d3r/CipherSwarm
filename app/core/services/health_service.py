import asyncio
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from typing import Any, cast

import redis.asyncio as aioredis
from loguru import logger
from minio.error import S3Error
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.services.storage_service import StorageService, get_storage_service
from app.db.health import check_database_health
from app.models.agent import Agent
from app.models.campaign import Campaign
from app.models.hash_list import HashList
from app.models.task import Task
from app.models.user import User
from app.schemas.health import (
    AgentHealthSummary,
    MinioHealth,
    PostgresHealth,
    RedisHealth,
    SystemHealthOverview,
)

# Simple in-memory cache for expensive metrics (per-process, not distributed)
# TODO: This should be replaced with cashews
_health_cache: dict[str, tuple[float, Any]] = {}


async def get_system_health_overview_service(
    db: AsyncSession,
    _current_user: User,
    get_storage_service_fn: Callable[[], StorageService] = get_storage_service,
) -> SystemHealthOverview:
    now = datetime.now(UTC).timestamp()
    cache_ttl = 10  # seconds
    cache_key = "system_health_overview"
    if cache_key in _health_cache:
        ts, value = _health_cache[cache_key]
        if now - ts < cache_ttl:
            return cast("SystemHealthOverview", value)
    # MinIO health
    minio_status = "unreachable"
    minio_latency = None
    minio_error = None
    minio_bucket_count = None
    try:
        storage = get_storage_service_fn()
        start = datetime.now(UTC)
        buckets = await asyncio.to_thread(storage.client.list_buckets)
        minio_latency = (datetime.now(UTC) - start).total_seconds()
        minio_status = "healthy"
        minio_bucket_count = len(buckets)
    except (RuntimeError, ConnectionError, S3Error) as e:
        minio_error = str(e)
        logger.error(f"MinIO health check failed: {e}")
        minio_status = "unreachable"
    minio = MinioHealth(
        status=minio_status,
        latency=minio_latency,
        error=minio_error,
        bucket_count=minio_bucket_count,
    )
    # Redis health
    redis_status = "unreachable"
    redis_latency = None
    redis_error = None
    redis_memory = None
    redis_connections = None
    try:
        redis = aioredis.Redis(
            host=settings.REDIS_HOST, port=settings.REDIS_PORT, decode_responses=True
        )
        start = datetime.now(UTC)
        pong = await redis.ping()
        redis_latency = (datetime.now(UTC) - start).total_seconds()
        if pong:
            redis_status = "healthy"
        info = await redis.info()
        redis_memory = info.get("used_memory")
        redis_connections = info.get("connected_clients")
        await redis.close()
    except (RuntimeError, ConnectionError, aioredis.RedisError) as e:
        redis_error = str(e)
        logger.error(f"Redis health check failed: {e}")
        redis_status = "unreachable"
    redis_health = RedisHealth(
        status=redis_status,
        latency=redis_latency,
        error=redis_error,
        memory_usage=redis_memory,
        active_connections=redis_connections,
    )
    # Postgres health
    pg_status = "unreachable"
    pg_latency = None
    pg_error = None
    try:
        start = datetime.now(UTC)
        healthy, msg = await check_database_health(db)
        pg_latency = (datetime.now(UTC) - start).total_seconds()
        if healthy:
            pg_status = "healthy"
        else:
            pg_status = "unreachable"
            pg_error = msg
    except (RuntimeError, ConnectionError) as e:
        pg_error = str(e)
        logger.error(f"Postgres health check failed: {e}")
        pg_status = "unreachable"
    postgres = PostgresHealth(
        status=pg_status,
        latency=pg_latency,
        error=pg_error,
    )
    # Agent/campaign/task/hashlist summary
    online_cutoff = datetime.now(UTC) - timedelta(minutes=2)
    total_agents = await db.scalar(select(func.count()).select_from(Agent))
    online_agents = await db.scalar(
        select(func.count())
        .select_from(Agent)
        .where(Agent.last_seen_at >= online_cutoff, Agent.enabled)
    )
    total_campaigns = await db.scalar(select(func.count()).select_from(Campaign))
    total_tasks = await db.scalar(select(func.count()).select_from(Task))
    total_hashlists = await db.scalar(select(func.count()).select_from(HashList))
    agent_summary = AgentHealthSummary(
        total_agents=total_agents or 0,
        online_agents=online_agents or 0,
        total_campaigns=total_campaigns or 0,
        total_tasks=total_tasks or 0,
        total_hashlists=total_hashlists or 0,
    )
    overview = SystemHealthOverview(
        minio=minio,
        redis=redis_health,
        postgres=postgres,
        agents=agent_summary,
    )
    _health_cache[cache_key] = (now, overview)
    return overview
