from typing import NoReturn

import pytest
from httpx import AsyncClient, codes
from minio import Minio
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.main import app
from app.models.user import UserRole
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_health_overview_success(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
    minio_client: Minio,
) -> None:
    user = await user_factory.create_async()
    async_client.cookies.set("access_token", create_access_token(user.id))
    resp = await async_client.get("/api/v1/web/health/overview")
    assert resp.status_code == codes.OK
    data = resp.json()
    assert "minio" in data
    assert "redis" in data
    assert "postgres" in data
    assert "agents" in data
    # MinIO
    minio = data["minio"]
    assert minio["status"] in ("healthy", "degraded", "unreachable")
    # Redis
    redis = data["redis"]
    assert redis["status"] in ("healthy", "degraded", "unreachable")
    # Postgres
    pg = data["postgres"]
    assert pg["status"] in ("healthy", "degraded", "unreachable")
    # Agents
    agents = data["agents"]
    assert isinstance(agents["total_agents"], int)
    assert isinstance(agents["online_agents"], int)
    assert isinstance(agents["total_campaigns"], int)
    assert isinstance(agents["total_tasks"], int)
    assert isinstance(agents["total_hashlists"], int)


@pytest.mark.asyncio
async def test_health_overview_minio_unavailable(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    # Clear the health cache to force a fresh check
    from app.core.services import health_service

    health_service._health_cache.clear()

    def fail_minio() -> NoReturn:
        raise RuntimeError("MinIO unavailable")

    # Override the dependency to inject the failing storage service
    from app.api.v1.endpoints.web import health as health_module

    app.dependency_overrides[health_module.get_storage_service_dep] = lambda: fail_minio

    user = await user_factory.create_async()
    async_client.cookies.set("access_token", create_access_token(user.id))
    resp = await async_client.get("/api/v1/web/health/overview")
    assert resp.status_code == codes.OK
    data = resp.json()
    assert data["minio"]["status"] == "unreachable"
    assert data["minio"]["error"] is not None
    # Restore
    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_health_components_success_admin(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
    minio_client: Minio,
) -> None:
    """Test components endpoint with admin user - should get detailed metrics"""
    # Clear cache to ensure fresh data
    from app.core.services import health_service

    health_service._health_cache.clear()

    admin_user = await user_factory.create_async(role=UserRole.ADMIN, is_superuser=True)
    async_client.cookies.set("access_token", create_access_token(admin_user.id))

    resp = await async_client.get("/api/v1/web/health/components")
    assert resp.status_code == codes.OK
    data = resp.json()

    # Should have all three components
    assert "minio" in data
    assert "redis" in data
    assert "postgres" in data

    # MinIO should have detailed fields for admin
    minio = data["minio"]
    assert minio["status"] in ("healthy", "degraded", "unreachable")
    if minio["status"] == "healthy":
        # Admin should see detailed metrics
        assert "object_count" in minio
        assert "storage_usage" in minio
        assert isinstance(minio.get("object_count"), (int, type(None)))
        assert isinstance(minio.get("storage_usage"), (int, type(None)))

    # Redis should have detailed fields for admin
    redis = data["redis"]
    assert redis["status"] in ("healthy", "degraded", "unreachable")
    if redis["status"] == "healthy":
        # Admin should see detailed metrics
        assert "keyspace_keys" in redis
        assert "evicted_keys" in redis
        assert "expired_keys" in redis
        assert "max_memory" in redis

    # PostgreSQL should have detailed fields for admin
    postgres = data["postgres"]
    assert postgres["status"] in ("healthy", "degraded", "unreachable")
    if postgres["status"] == "healthy":
        # Admin should see detailed metrics
        assert "active_connections" in postgres
        assert "max_connections" in postgres
        assert "long_running_queries" in postgres
        assert "database_size" in postgres


@pytest.mark.asyncio
async def test_health_components_success_non_admin(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
    minio_client: Minio,
) -> None:
    """Test components endpoint with non-admin user - should get basic metrics only"""
    # Clear cache to ensure fresh data
    from app.core.services import health_service

    health_service._health_cache.clear()

    regular_user = await user_factory.create_async(
        role=UserRole.ANALYST, is_superuser=False
    )
    async_client.cookies.set("access_token", create_access_token(regular_user.id))

    resp = await async_client.get("/api/v1/web/health/components")
    assert resp.status_code == codes.OK
    data = resp.json()

    # Should have all three components
    assert "minio" in data
    assert "redis" in data
    assert "postgres" in data

    # MinIO should NOT have detailed fields for non-admin
    minio = data["minio"]
    assert minio["status"] in ("healthy", "degraded", "unreachable")
    # Should have basic fields
    assert "bucket_count" in minio
    # Should NOT have admin-only fields
    assert "object_count" not in minio
    assert "storage_usage" not in minio

    # Redis should NOT have detailed fields for non-admin
    redis = data["redis"]
    assert redis["status"] in ("healthy", "degraded", "unreachable")
    # Should have basic fields
    assert "memory_usage" in redis
    assert "active_connections" in redis
    # Should NOT have admin-only fields
    assert "keyspace_keys" not in redis
    assert "evicted_keys" not in redis
    assert "expired_keys" not in redis
    assert "max_memory" not in redis

    # PostgreSQL should NOT have detailed fields for non-admin
    postgres = data["postgres"]
    assert postgres["status"] in ("healthy", "degraded", "unreachable")
    # Should have basic fields
    assert "latency" in postgres
    # Should NOT have admin-only fields
    assert "active_connections" not in postgres
    assert "max_connections" not in postgres
    assert "long_running_queries" not in postgres
    assert "database_size" not in postgres


@pytest.mark.asyncio
async def test_health_components_unauthorized(
    async_client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Test components endpoint without authentication"""
    resp = await async_client.get("/api/v1/web/health/components")
    assert resp.status_code == codes.UNAUTHORIZED


@pytest.mark.asyncio
async def test_health_components_caching(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
    minio_client: Minio,
) -> None:
    """Test that components endpoint properly caches results"""
    # Clear cache to start fresh
    from app.core.services import health_service

    health_service._health_cache.clear()

    admin_user = await user_factory.create_async(role=UserRole.ADMIN, is_superuser=True)
    async_client.cookies.set("access_token", create_access_token(admin_user.id))

    # First request should populate cache
    resp1 = await async_client.get("/api/v1/web/health/components")
    assert resp1.status_code == codes.OK

    # Second request should use cache (verify cache key exists)
    resp2 = await async_client.get("/api/v1/web/health/components")
    assert resp2.status_code == codes.OK

    # Responses should be identical (from cache)
    assert resp1.json() == resp2.json()

    # Verify cache key exists for admin
    assert any(
        "system_health_components_admin_True" in key
        for key in health_service._health_cache
    )


@pytest.mark.asyncio
async def test_health_components_different_cache_for_admin_vs_user(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
    minio_client: Minio,
) -> None:
    """Test that admin and non-admin users have separate cache entries"""
    # Clear cache to start fresh
    from app.core.services import health_service

    health_service._health_cache.clear()

    # Request as admin
    admin_user = await user_factory.create_async(role=UserRole.ADMIN, is_superuser=True)
    async_client.cookies.set("access_token", create_access_token(admin_user.id))
    resp_admin = await async_client.get("/api/v1/web/health/components")
    assert resp_admin.status_code == codes.OK

    # Request as regular user
    regular_user = await user_factory.create_async(
        role=UserRole.ANALYST, is_superuser=False
    )
    async_client.cookies.set("access_token", create_access_token(regular_user.id))
    resp_user = await async_client.get("/api/v1/web/health/components")
    assert resp_user.status_code == codes.OK

    # Should have separate cache entries
    cache_keys = list(health_service._health_cache.keys())
    assert any("system_health_components_admin_True" in key for key in cache_keys)
    assert any("system_health_components_admin_False" in key for key in cache_keys)

    # Admin response should have more fields than user response
    admin_data = resp_admin.json()
    user_data = resp_user.json()

    # Admin should have detailed MinIO metrics
    if admin_data["minio"]["status"] == "healthy":
        assert "object_count" in admin_data["minio"]
        assert "object_count" not in user_data["minio"]
