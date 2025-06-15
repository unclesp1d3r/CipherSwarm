"""
Tests for Control API system endpoints.

These tests verify that system endpoints return proper information
and require authentication.
"""

from http import HTTPStatus
from uuid import UUID

import pytest
from httpx import AsyncClient

from app.core.config import settings


@pytest.mark.asyncio
async def test_get_system_version_with_auth(
    async_client: AsyncClient,
    api_user_with_project: tuple[UUID, int, str],
) -> None:
    """Test that authenticated user can get system version."""
    _, _, api_key = api_user_with_project

    # Test getting system version
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get("/api/v1/control/system/version", headers=headers)

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert "version" in data
    assert "project_name" in data
    assert data["version"] == settings.VERSION
    assert data["project_name"] == settings.PROJECT_NAME


@pytest.mark.asyncio
async def test_get_system_version_without_auth(
    async_client: AsyncClient,
) -> None:
    """Test that unauthenticated request returns 401."""
    resp = await async_client.get("/api/v1/control/system/version")

    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_get_system_version_invalid_token(
    async_client: AsyncClient,
) -> None:
    """Test that invalid token returns 401."""
    headers = {"Authorization": "Bearer invalid_token"}
    resp = await async_client.get("/api/v1/control/system/version", headers=headers)

    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_get_system_status_with_auth(
    async_client: AsyncClient,
    api_user_with_project: tuple[UUID, int, str],
) -> None:
    """Test that authenticated user can get system status."""
    _, _, api_key = api_user_with_project

    # Test getting system status
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get("/api/v1/control/system/status", headers=headers)

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    # Should have health information for core components
    assert "minio" in data
    assert "redis" in data
    assert "postgres" in data
    assert "agents" in data


@pytest.mark.asyncio
async def test_get_system_stats_with_auth(
    async_client: AsyncClient,
    api_user_with_project: tuple[UUID, int, str],
) -> None:
    """Test that authenticated user can get system stats."""
    _, _, api_key = api_user_with_project

    # Test getting system stats
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get("/api/v1/control/system/stats", headers=headers)

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    # Should have dashboard summary information
    assert "active_agents" in data
    assert "total_agents" in data
    assert "running_tasks" in data
    assert "total_tasks" in data
    assert "recently_cracked_hashes" in data
    assert "resource_usage" in data


@pytest.mark.asyncio
async def test_get_system_queues_with_auth(
    async_client: AsyncClient,
    api_user_with_project: tuple[UUID, int, str],
) -> None:
    """Test that authenticated user can get queue status."""
    _, _, api_key = api_user_with_project

    # Test getting queue status
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get("/api/v1/control/system/queues", headers=headers)

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()

    # Should have queue status information
    assert "overall_status" in data
    assert "redis_available" in data
    assert "queues" in data
    assert "total_pending_jobs" in data
    assert "total_running_jobs" in data
    assert "recent_activity" in data

    # Overall status should be one of the valid values
    assert data["overall_status"] in ["healthy", "degraded", "unhealthy"]

    # Should have at least the asyncio queues
    assert isinstance(data["queues"], list)
    assert len(data["queues"]) >= 2  # At least cracking_tasks and upload_processing

    # Check queue structure
    for queue in data["queues"]:
        assert "name" in queue
        assert "type" in queue
        assert "pending_jobs" in queue
        assert "running_jobs" in queue
        assert "failed_jobs" in queue
        assert "status" in queue
        assert queue["type"] in ["asyncio", "celery"]
        assert queue["status"] in ["active", "idle", "inactive"]


@pytest.mark.asyncio
async def test_get_system_queues_without_auth(
    async_client: AsyncClient,
) -> None:
    """Test that unauthenticated request returns 401."""
    resp = await async_client.get("/api/v1/control/system/queues")

    assert resp.status_code == HTTPStatus.UNAUTHORIZED
