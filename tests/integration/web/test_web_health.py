from typing import NoReturn

import pytest
from httpx import AsyncClient, codes
from minio import Minio
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.main import app
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
