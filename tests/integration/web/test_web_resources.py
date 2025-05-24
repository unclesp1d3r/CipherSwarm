import json
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
    authenticated_async_client: AsyncClient, db_session: AsyncSession
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        line_count=10,
        byte_size=100,
    )
    url = f"/api/v1/web/resources/{resource.id}/content"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["resource"]["file_name"] == resource.file_name
    assert data["resource"]["resource_type"] == resource.resource_type.value
    assert data["editable"] is True
    assert isinstance(data["content"], str)


@pytest.mark.asyncio
async def test_get_resource_content_dynamic_word_list(
    authenticated_async_client: AsyncClient, db_session: AsyncSession
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.DYNAMIC_WORD_LIST,
        line_count=10,
        byte_size=100,
    )
    url = f"/api/v1/web/resources/{resource.id}/content"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.FORBIDDEN
    data = resp.json()
    assert "read-only" in data["detail"]


@pytest.mark.asyncio
async def test_get_resource_content_oversize(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_LINES", 5)
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_SIZE_MB", 1)
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        line_count=10,
        byte_size=100,
    )
    url = f"/api/v1/web/resources/{resource.id}/content"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.FORBIDDEN
    data = resp.json()
    assert "too large" in data["detail"]


@pytest.mark.asyncio
async def test_get_resource_content_oversize_config(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_LINES", 3)
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_SIZE_MB", 1)
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        line_count=10,
        byte_size=100,
    )
    url = f"/api/v1/web/resources/{resource.id}/content"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.FORBIDDEN
    data = resp.json()
    assert "too large" in data["detail"]


@pytest.mark.asyncio
async def test_get_resource_content_not_found(
    authenticated_async_client: AsyncClient,
) -> None:
    url = f"/api/v1/web/resources/{uuid4()}/content"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.NOT_FOUND
    data = resp.json()
    assert "Resource not found" in data["detail"]


INITIAL_LINE_COUNT = 2
ADDED_LINE_COUNT = 3
FINAL_LINE_COUNT = 2


@pytest.mark.asyncio
async def test_resource_line_editing(
    authenticated_async_client: AsyncClient, db_session: AsyncSession
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
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.FORBIDDEN
    assert "not editable" in resp.text or "forbidden" in resp.text


@pytest.mark.asyncio
async def test_resource_line_editing_html(
    authenticated_async_client: AsyncClient, db_session: AsyncSession
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
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["resource_id"] == str(resource.id)
    assert any(line["content"] == "alpha" for line in data["lines"])
    # Add a line
    resp = await authenticated_async_client.post(url, json={"line": "gamma"})
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # List again (should be 3)
    resp = await authenticated_async_client.get(url)
    data = resp.json()
    assert any(line["content"] == "gamma" for line in data["lines"])
    # Update line 1
    patch_url = f"/api/v1/web/resources/{resource.id}/lines/1"
    resp = await authenticated_async_client.patch(patch_url, json={"line": "delta"})
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # Delete line 2
    delete_url = f"/api/v1/web/resources/{resource.id}/lines/2"
    resp = await authenticated_async_client.delete(delete_url)
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # List again (should be 2)
    resp = await authenticated_async_client.get(url)
    data = resp.json()
    assert any(line["content"] == "delta" for line in data["lines"])
    assert not any(line["content"] == "gamma" for line in data["lines"])


@pytest.mark.asyncio
async def test_file_backed_resource_line_editing(
    authenticated_async_client: AsyncClient, db_session: AsyncSession
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
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert any(line["content"] == "alpha" for line in data["lines"])
    assert any(line["content"] == "bravo" for line in data["lines"])
    # Add a line
    resp = await authenticated_async_client.post(url, json={"line": "charlie"})
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # List again
    resp = await authenticated_async_client.get(url)
    data = resp.json()
    assert any(line["content"] == "charlie" for line in data["lines"])
    # Update line 1
    patch_url = f"/api/v1/web/resources/{resource.id}/lines/1"
    resp = await authenticated_async_client.patch(patch_url, json={"line": "beta"})
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # Delete line 0
    delete_url = f"/api/v1/web/resources/{resource.id}/lines/0"
    resp = await authenticated_async_client.delete(delete_url)
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
    resp = await authenticated_async_client.post(
        mask_url, json={"line": "bad mask with space"}
    )
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
    data = resp.json()
    assert "Invalid mask syntax" in json.dumps(data)


@pytest.mark.asyncio
async def test_resource_line_editing_forbidden_types(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    # Dynamic word list (should be forbidden)
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.DYNAMIC_WORD_LIST,
        source="generated",
        file_name="dynamic_wordlist.txt",
        download_url="",
        checksum="",
        content=None,
        line_count=10,
        byte_size=100,
    )
    url = f"/api/v1/web/resources/{resource.id}/lines"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.FORBIDDEN
    assert "disabled" in resp.text or "read-only" in resp.text
    # Oversize resource (should be forbidden)
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_LINES", 1)
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_SIZE_MB", 1)
    resource2 = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        source="upload",
        file_name="oversize_wordlist.txt",
        download_url="",
        checksum="",
        content=MutableDict({"lines": MutableList(["a", "b"])}),
        line_count=2,
        byte_size=2000000,
    )
    url2 = f"/api/v1/web/resources/{resource2.id}/lines"
    resp2 = await authenticated_async_client.get(url2)
    assert resp2.status_code == HTTPStatus.FORBIDDEN
    assert "disabled" in resp2.text or "too large" in resp2.text
    # Try POST, PATCH, DELETE for forbidden resource
    resp3 = await authenticated_async_client.post(url2, json={"line": "c"})
    assert resp3.status_code == HTTPStatus.FORBIDDEN
    resp4 = await authenticated_async_client.patch(f"{url2}/0", json={"line": "d"})
    assert resp4.status_code == HTTPStatus.FORBIDDEN
    resp5 = await authenticated_async_client.delete(f"{url2}/0")
    assert resp5.status_code == HTTPStatus.FORBIDDEN


@pytest.mark.asyncio
async def test_resource_lines_batch_validation(
    authenticated_async_client: AsyncClient, db_session: AsyncSession
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    # Create a mask list resource with one valid and one invalid line
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.MASK_LIST,
        source="upload",
        file_name="test_masklist.txt",
        download_url="",
        checksum="",
        content=MutableDict(
            {"lines": MutableList(["?d?d?d?d", "bad mask with space"])}
        ),
        line_count=2,
        byte_size=16,
    )
    url = f"/api/v1/web/resources/{resource.id}/lines?validate=true"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    # Should return HTML fragment with both lines and validation status
    assert "?d?d?d?d" in resp.text
    assert "bad mask with space" in resp.text
    # The invalid line should have an error message in the HTML
    assert "Invalid mask syntax" in resp.text


@pytest.mark.asyncio
async def test_get_resource_preview_normal(
    authenticated_async_client: AsyncClient, db_session: AsyncSession
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        file_name="preview_wordlist.txt",
        content=MutableDict({"lines": MutableList([f"word{i}" for i in range(20)])}),
        line_count=20,
        byte_size=200,
    )
    url = f"/api/v1/web/resources/{resource.id}/preview"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["resource"]["file_name"] == "preview_wordlist.txt"
    assert data["preview_lines"][:10] == [f"word{i}" for i in range(10)]
    assert data["preview_error"] is None
    assert data["max_preview_lines"] == 10


@pytest.mark.asyncio
async def test_get_resource_preview_non_list_content(
    authenticated_async_client: AsyncClient, db_session: AsyncSession
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        file_name="bad_content.txt",
        content=MutableDict({"lines": "notalist"}),
        line_count=1,
        byte_size=10,
    )
    url = f"/api/v1/web/resources/{resource.id}/preview"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    assert "Resource lines are not a list." in resp.text


@pytest.mark.asyncio
async def test_get_resource_preview_no_content(
    authenticated_async_client: AsyncClient, db_session: AsyncSession
) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment]
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        file_name="no_content.txt",
        content=None,
        line_count=0,
        byte_size=0,
    )
    url = f"/api/v1/web/resources/{resource.id}/preview"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    assert "No preview available for this resource type." in resp.text


@pytest.mark.asyncio
async def test_get_resource_preview_not_found(
    authenticated_async_client: AsyncClient,
) -> None:
    url = f"/api/v1/web/resources/{uuid4()}/preview"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.NOT_FOUND
    assert "Resource not found" in resp.text
