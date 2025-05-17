from http import HTTPStatus
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.ext.mutable import MutableDict, MutableList

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


INITIAL_LINE_COUNT = 2
ADDED_LINE_COUNT = 3
FINAL_LINE_COUNT = 2


@pytest.mark.asyncio
async def test_resource_line_editing(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.EPHEMERAL_WORD_LIST,
        source="ephemeral",
        file_name="ephemeral_wordlist.txt",
        download_url="",
        checksum="",
        content=MutableDict({"lines": ["password1", "password2"]}),
        line_count=2,
        byte_size=20,
    )
    # List lines (should be forbidden)
    url = f"/api/v1/web/resources/{resource.id}/lines"
    resp = await async_client.get(url)
    assert resp.status_code == HTTPStatus.FORBIDDEN
    assert "not editable" in resp.text or "forbidden" in resp.text


@pytest.mark.asyncio
async def test_resource_line_editing_html(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        source="upload",
        file_name="test_wordlist.txt",
        download_url="",
        checksum="",
        content=MutableDict({"lines": MutableList(["alpha", "beta"])}),
        line_count=2,
        byte_size=20,
    )
    url = f"/api/v1/web/resources/{resource.id}/lines"
    resp = await async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    assert "text/html" in resp.headers["content-type"]
    assert "<ul>" in resp.text
    assert "alpha" in resp.text
    # Add a line
    resp = await async_client.post(url, json={"line": "gamma"})
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # List again (should be 3)
    resp = await async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    assert "<ul>" in resp.text
    assert "gamma" in resp.text
    # Update line 1
    patch_url = f"/api/v1/web/resources/{resource.id}/lines/1"
    resp = await async_client.patch(patch_url, json={"line": "delta"})
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # Delete line 2
    delete_url = f"/api/v1/web/resources/{resource.id}/lines/2"
    resp = await async_client.delete(delete_url)
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # List again (should be 2)
    resp = await async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    assert "<ul>" in resp.text
    assert "delta" in resp.text
    # 'gamma' should have been deleted, so it should not be present
    assert "gamma" not in resp.text


@pytest.mark.asyncio
async def test_file_backed_resource_line_editing(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        source="upload",
        file_name="test_wordlist.txt",
        download_url="",
        checksum="",
        content=MutableDict({"lines": MutableList(["alpha", "bravo"])}),
        line_count=2,
        byte_size=10,
    )
    url = f"/api/v1/web/resources/{resource.id}/lines"
    # List lines
    resp = await async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    assert "text/html" in resp.headers["content-type"]
    assert "<ul" in resp.text or "<li" in resp.text
    assert "alpha" in resp.text
    assert "bravo" in resp.text
    # Add a line
    resp = await async_client.post(url, json={"line": "charlie"})
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # List again
    resp = await async_client.get(url)
    assert "charlie" in resp.text
    # Update line 1
    patch_url = f"/api/v1/web/resources/{resource.id}/lines/1"
    resp = await async_client.patch(patch_url, json={"line": "beta"})
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # Delete line 0
    delete_url = f"/api/v1/web/resources/{resource.id}/lines/0"
    resp = await async_client.delete(delete_url)
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # Validation error (mask_list, invalid mask)
    mask_resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.MASK_LIST,
        source="upload",
        file_name="test_masklist.txt",
        download_url="",
        checksum="",
        content=MutableDict({"lines": MutableList(["?d?d?d?d"])}),
        line_count=1,
        byte_size=8,
    )
    mask_url = f"/api/v1/web/resources/{mask_resource.id}/lines"
    resp = await async_client.post(mask_url, json={"line": "bad mask with space"})
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
    assert "Invalid mask syntax" in resp.text
