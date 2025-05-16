from http import HTTPStatus
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import config as core_config
from app.models.attack_resource_file import AttackResourceType
from tests.factories.attack_resource_file_factory import AttackResourceFileFactory


@pytest.mark.asyncio
async def test_get_resource_content_editable(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        line_count=10,
        byte_size=100,
    )
    url = f"/api/v1/web/resources/{resource.id}/content"
    resp = await async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    assert "textarea" in resp.text
    assert resource.file_name in resp.text
    assert resource.resource_type.value in resp.text


@pytest.mark.asyncio
async def test_get_resource_content_dynamic_word_list(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.DYNAMIC_WORD_LIST,
        line_count=10,
        byte_size=100,
    )
    url = f"/api/v1/web/resources/{resource.id}/content"
    resp = await async_client.get(url)
    assert resp.status_code == HTTPStatus.FORBIDDEN
    assert "read-only" in resp.text


@pytest.mark.asyncio
async def test_get_resource_content_oversize(
    async_client: AsyncClient, db_session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    # Patch config settings directly
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_LINES", 5)
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_SIZE_MB", 1)
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        line_count=10,
        byte_size=100,
    )
    url = f"/api/v1/web/resources/{resource.id}/content"
    resp = await async_client.get(url)
    assert resp.status_code == HTTPStatus.FORBIDDEN
    assert "too large to edit inline" in resp.text


@pytest.mark.asyncio
async def test_get_resource_content_oversize_config(
    async_client: AsyncClient, db_session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Test that config-based resource edit limits are enforced."""
    # Patch config settings directly
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_LINES", 3)
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_SIZE_MB", 1)
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        line_count=10,
        byte_size=100,
    )
    url = f"/api/v1/web/resources/{resource.id}/content"
    resp = await async_client.get(url)
    assert resp.status_code == HTTPStatus.FORBIDDEN
    assert "too large to edit inline" in resp.text


@pytest.mark.asyncio
async def test_get_resource_content_not_found(async_client: AsyncClient) -> None:
    url = f"/api/v1/web/resources/{uuid4()}/content"
    resp = await async_client.get(url)
    assert resp.status_code == HTTPStatus.NOT_FOUND
    assert "Resource not found" in resp.text
