import io
import json
from http import HTTPStatus
from typing import Any
from uuid import uuid4

import pytest
from httpx import AsyncClient
from minio import Minio
from minio.error import MinioException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.ext.mutable import MutableDict, MutableList

from app.core import config as core_config
from app.core.config import settings
from app.models.attack import Attack
from app.models.attack_resource_file import AttackResourceFile, AttackResourceType
from app.models.campaign import Campaign
from tests.factories.attack_resource_file_factory import AttackResourceFileFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory

INITIAL_LINE_COUNT = 2
ADDED_LINE_COUNT = 3
FINAL_LINE_COUNT = 2


@pytest.mark.asyncio
async def test_get_resource_content_editable(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        line_count=10,
        byte_size=100,
    )
    url = f"/api/v1/web/resources/{resource.id}/content"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data.get("file_name") == resource.file_name
    assert data.get("resource_type") == resource.resource_type.value
    assert data.get("editable") is True
    assert isinstance(data.get("content"), str)


@pytest.mark.asyncio
async def test_get_resource_content_dynamic_word_list(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
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
    attack_resource_file_factory: AttackResourceFileFactory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_LINES", 5)
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_SIZE_MB", 1)
    resource = await attack_resource_file_factory.create_async(
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
    attack_resource_file_factory: AttackResourceFileFactory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_LINES", 3)
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_SIZE_MB", 1)
    resource = await attack_resource_file_factory.create_async(
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


@pytest.mark.asyncio
async def test_resource_line_editing(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
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
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
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
    assert data.get("resource_id") == str(resource.id)
    assert any(line.get("content") == "alpha" for line in data.get("lines", []))

    # Add a line
    resp = await authenticated_async_client.post(url, json={"line": "gamma"})
    assert resp.status_code == HTTPStatus.NO_CONTENT

    # List again (should be 3)
    resp = await authenticated_async_client.get(url)
    data = resp.json()
    assert any(line.get("content") == "gamma" for line in data.get("lines", []))

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
    assert any(line.get("content") == "delta" for line in data.get("lines", []))
    assert not any(line.get("content") == "gamma" for line in data.get("lines", []))


@pytest.mark.asyncio
async def test_file_backed_resource_line_editing(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
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
    assert any(line.get("content") == "alpha" for line in data.get("lines", []))
    assert any(line.get("content") == "bravo" for line in data.get("lines", []))
    # Add a line
    resp = await authenticated_async_client.post(url, json={"line": "charlie"})
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # List again
    resp = await authenticated_async_client.get(url)
    data = resp.json()
    assert any(line.get("content") == "charlie" for line in data.get("lines", []))
    # Update line 1
    patch_url = f"/api/v1/web/resources/{resource.id}/lines/1"
    resp = await authenticated_async_client.patch(patch_url, json={"line": "beta"})
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # Delete line 0
    delete_url = f"/api/v1/web/resources/{resource.id}/lines/0"
    resp = await authenticated_async_client.delete(delete_url)
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # Validation error (mask_list, invalid mask)
    mask_resource = await attack_resource_file_factory.create_async(
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
    attack_resource_file_factory: AttackResourceFileFactory,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    # Dynamic word list (should be forbidden)
    resource = await attack_resource_file_factory.create_async(
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
    error_detail = resp.json().get("detail")
    assert resp.status_code == HTTPStatus.FORBIDDEN
    assert (
        "disabled" in error_detail
        or "read-only" in error_detail
        or "not editable" in error_detail
    )

    # Oversize resource (should be forbidden)
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_LINES", 1)
    monkeypatch.setattr(core_config.settings, "RESOURCE_EDIT_MAX_SIZE_MB", 1)
    resource2 = await attack_resource_file_factory.create_async(
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
    error_detail = resp2.json().get("detail")
    assert (
        "disabled" in error_detail
        or "too large" in error_detail
        or "not editable" in error_detail
    )

    # Try POST, PATCH, DELETE for forbidden resource
    resp3 = await authenticated_async_client.post(url2, json={"line": "c"})
    assert resp3.status_code == HTTPStatus.FORBIDDEN

    resp4 = await authenticated_async_client.patch(f"{url2}/0", json={"line": "d"})
    assert resp4.status_code == HTTPStatus.FORBIDDEN

    resp5 = await authenticated_async_client.delete(f"{url2}/0")
    assert resp5.status_code == HTTPStatus.FORBIDDEN


@pytest.mark.asyncio
async def test_resource_lines_batch_validation(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    # Create a mask list resource with one valid and one invalid line
    resource = await attack_resource_file_factory.create_async(
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
    data = resp.json()
    validation_errors = data.get("lines", [])
    assert any(line.get("content") == "?d?d?d?d" for line in validation_errors)
    assert any(
        line.get("content") == "bad mask with space" for line in validation_errors
    )
    assert any(
        line.get("error_message") == "Invalid mask syntax" for line in validation_errors
    )


@pytest.mark.asyncio
async def test_get_resource_preview_normal(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
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
    assert data.get("file_name") == "preview_wordlist.txt"
    assert data.get("preview_lines")[:10] == [f"word{i}" for i in range(10)]
    assert data.get("preview_error") is None
    assert data.get("max_preview_lines") == 10


@pytest.mark.asyncio
async def test_get_resource_preview_non_list_content(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
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
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
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


@pytest.mark.asyncio
async def test_upload_resource_metadata_detect_type_success(
    authenticated_async_client: AsyncClient,
) -> None:
    url = "/api/v1/web/resources/"
    # .rule extension
    resp = await authenticated_async_client.post(
        url,
        data={
            "file_name": "test.rule",
            "resource_type": "word_list",  # Should be overridden
            "detect_type": "true",
        },
    )
    assert resp.status_code == HTTPStatus.CREATED
    data = resp.json()
    assert data["resource"]["resource_type"] == "rule_list"
    # .mask extension
    resp = await authenticated_async_client.post(
        url,
        data={
            "file_name": "test.mask",
            "resource_type": "word_list",
            "detect_type": "true",
        },
    )
    assert resp.status_code == HTTPStatus.CREATED
    data = resp.json()
    assert data["resource"]["resource_type"] == "mask_list"
    # .charset extension
    resp = await authenticated_async_client.post(
        url,
        data={
            "file_name": "test.charset",
            "resource_type": "word_list",
            "detect_type": "true",
        },
    )
    assert resp.status_code == HTTPStatus.CREATED
    data = resp.json()
    assert data["resource"]["resource_type"] == "charset"
    # .txt extension
    resp = await authenticated_async_client.post(
        url,
        data={
            "file_name": "test.txt",
            "resource_type": "mask_list",
            "detect_type": "true",
        },
    )
    assert resp.status_code == HTTPStatus.CREATED
    data = resp.json()
    assert data["resource"]["resource_type"] == "word_list"
    # .wordlist extension
    resp = await authenticated_async_client.post(
        url,
        data={
            "file_name": "test.wordlist",
            "resource_type": "mask_list",
            "detect_type": "true",
        },
    )
    assert resp.status_code == HTTPStatus.CREATED
    data = resp.json()
    assert data["resource"]["resource_type"] == "word_list"


@pytest.mark.asyncio
async def test_upload_resource_metadata_detect_type_unknown(
    authenticated_async_client: AsyncClient,
) -> None:
    url = "/api/v1/web/resources/"
    resp = await authenticated_async_client.post(
        url,
        data={
            "file_name": "test.unknown",
            "resource_type": "word_list",
            "detect_type": "true",
        },
    )
    assert resp.status_code == HTTPStatus.BAD_REQUEST
    assert "Could not detect resource_type" in resp.text


@pytest.mark.asyncio
async def test_upload_resource_metadata_detect_type_false(
    authenticated_async_client: AsyncClient,
) -> None:
    url = "/api/v1/web/resources/"
    resp = await authenticated_async_client.post(
        url,
        data={
            "file_name": "test.mask",
            "resource_type": "rule_list",
            "detect_type": "false",
        },
    )
    assert resp.status_code == HTTPStatus.CREATED
    data = resp.json()
    # Should use provided resource_type, not detected
    assert data["resource"]["resource_type"] == "rule_list"


@pytest.mark.asyncio
async def test_upload_resource_metadata_detect_type_overrides(
    authenticated_async_client: AsyncClient,
) -> None:
    url = "/api/v1/web/resources/"
    resp = await authenticated_async_client.post(
        url,
        data={
            "file_name": "test.mask",
            "resource_type": "word_list",
            "detect_type": "true",
        },
    )
    assert resp.status_code == HTTPStatus.CREATED
    data = resp.json()
    # Should override provided resource_type
    assert data["resource"]["resource_type"] == "mask_list"


@pytest.mark.asyncio
async def test_get_resource_upload_form_schema(
    authenticated_admin_client: AsyncClient,
) -> None:
    url = "/api/v1/web/resources/upload"
    resp = await authenticated_admin_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert "allowed_resource_types" in data
    assert {"mask_list", "rule_list", "word_list", "charset"}.issubset(
        set(data["allowed_resource_types"])
    )
    assert not any(
        t.startswith("ephemeral_") or t == "dynamic_word_list"
        for t in data["allowed_resource_types"]
    )
    assert isinstance(data["max_file_size_mb"], int)
    assert isinstance(data["max_line_count"], int)
    assert isinstance(data["minio_bucket"], str)
    assert isinstance(data["minio_endpoint"], str)
    assert isinstance(data["minio_secure"], bool)


@pytest.mark.asyncio
async def test_get_resource_edit_metadata(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        file_name="editme.txt",
        line_count=5,
        byte_size=50,
    )
    url = f"/api/v1/web/resources/{resource.id}/edit"
    resp = await authenticated_async_client.get(url)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["file_name"] == "editme.txt"
    assert data["resource_type"] == "word_list"
    assert "attacks" in data


@pytest.mark.asyncio
async def test_patch_update_resource_metadata(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        file_name="patchme.txt",
        line_count=5,
        byte_size=50,
        source="upload",
        used_for_modes=["dictionary"],
        line_format="freeform",
        line_encoding="utf-8",
    )
    url = f"/api/v1/web/resources/{resource.id}"
    patch_data = {
        "file_name": "patched.txt",
        "source": "generated",
        "used_for_modes": ["mask"],
        "line_format": "mask",
        "line_encoding": "ascii",
    }
    resp = await authenticated_async_client.patch(url, json=patch_data)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["file_name"] == "patched.txt"
    assert data["source"] == "generated"
    assert data["used_for_modes"] == ["mask"]
    assert data["line_format"] == "mask"
    assert data["line_encoding"] == "ascii"


@pytest.mark.asyncio
async def test_delete_resource_hard_delete(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
    minio_client: Minio,
) -> None:
    # Create and upload resource
    resource = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        file_name="deleteme.txt",
        line_count=5,
        byte_size=50,
        is_uploaded=True,
        download_url="s3://bucket/obj",
    )
    # Upload to MinIO
    bucket = settings.MINIO_BUCKET
    if not minio_client.bucket_exists(bucket):
        minio_client.make_bucket(bucket)
    minio_client.put_object(bucket, str(resource.id), io.BytesIO(b"testdata"), length=8)
    url = f"/api/v1/web/resources/{resource.id}"
    resp = await authenticated_async_client.delete(url)
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # Confirm hard delete
    obj = await db_session.get(AttackResourceFile, resource.id)
    assert obj is None
    # Confirm S3 deletion
    with pytest.raises(MinioException):
        minio_client.stat_object(bucket, str(resource.id))


@pytest.mark.asyncio
async def test_delete_resource_conflict_linked(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        file_name="linked.txt",
        line_count=5,
        byte_size=50,
        is_uploaded=True,
        download_url="s3://bucket/obj",
    )
    # Create required Project and HashList for FK constraints
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = Campaign(
        name="test_campaign",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.flush()
    # Link to attack
    attack = Attack(
        word_list_id=resource.id,
        name="test",
        attack_mode="dictionary",
        hash_list_id=hash_list.id,
        hash_list_url="",
        hash_list_checksum="",
        state="pending",
        hash_type_id=1,
        campaign_id=campaign.id,
    )
    db_session.add(attack)
    await db_session.commit()
    url = f"/api/v1/web/resources/{resource.id}"
    resp = await authenticated_async_client.delete(url)
    assert resp.status_code == HTTPStatus.CONFLICT
    assert "linked" in resp.text


@pytest.mark.asyncio
async def test_delete_resource_not_found(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    url = f"/api/v1/web/resources/{uuid4()}"
    resp = await authenticated_async_client.delete(url)
    assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_delete_resource_forbidden_types(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.DYNAMIC_WORD_LIST,
        file_name="forbidden.txt",
        line_count=5,
        byte_size=50,
    )
    url = f"/api/v1/web/resources/{resource.id}"
    resp = await authenticated_async_client.delete(url)
    assert resp.status_code in (HTTPStatus.FORBIDDEN, HTTPStatus.UNPROCESSABLE_ENTITY)


@pytest.mark.asyncio
async def test_patch_update_resource_file_label_and_tags(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        file_name="patchme.txt",
        file_label=None,
        tags=None,
        line_count=5,
        byte_size=50,
        source="upload",
    )
    url = f"/api/v1/web/resources/{resource.id}"
    # Valid file_label and tags
    patch_data: dict[str, Any] = {
        "file_label": "My Label",
        "tags": ["foo", "bar"],
    }
    resp = await authenticated_async_client.patch(url, json=patch_data)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["file_label"] == "My Label"
    assert data["tags"] == ["foo", "bar"]
    # file_label too long
    patch_data = {"file_label": "x" * 51}
    resp = await authenticated_async_client.patch(url, json=patch_data)
    assert resp.status_code in (
        HTTPStatus.UNPROCESSABLE_ENTITY,
        HTTPStatus.UNPROCESSABLE_ENTITY,
    )
    # tags not a list
    patch_data = {"tags": "notalist"}
    resp = await authenticated_async_client.patch(url, json=patch_data)
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
    # tags not all strings
    patch_data = {"tags": ["ok", 123]}
    resp = await authenticated_async_client.patch(url, json=patch_data)
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
    # unrestricted/project_id logic
    patch_data = {"unrestricted": True}
    resp = await authenticated_async_client.patch(url, json=patch_data)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["unrestricted"] is True
    # Should fail if project_id not set and unrestricted is False
    patch_data = {"unrestricted": False}
    resp = await authenticated_async_client.patch(url, json=patch_data)
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
    # Now set project_id (simulate valid project id as int)
    patch_data = {"unrestricted": False, "project_id": 1}
    resp = await authenticated_async_client.patch(url, json=patch_data)
    assert resp.status_code in (HTTPStatus.OK, HTTPStatus.UNPROCESSABLE_ENTITY)


@pytest.mark.asyncio
async def test_post_upload_resource_with_file_label_and_tags(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    url = "/api/v1/web/resources/"
    import json

    resp = await authenticated_async_client.post(
        url,
        data={
            "file_name": "test_upload.txt",
            "resource_type": "word_list",
            "file_label": "UploadLabel",
            "tags": json.dumps(["alpha", "beta"]),
        },
    )
    assert resp.status_code == HTTPStatus.CREATED
    # Should be persisted, but we only get meta back
    # Fetch detail to check
    from sqlalchemy import select

    from app.models.attack_resource_file import AttackResourceFile

    db_obj = await db_session.execute(
        select(AttackResourceFile).where(
            AttackResourceFile.file_name == "test_upload.txt"
        )
    )
    resource = db_obj.scalar_one()
    assert resource.file_label == "UploadLabel"
    assert resource.tags == ["alpha", "beta"]


@pytest.mark.asyncio
async def test_get_resource_detail_and_edit_includes_file_label_and_tags(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    resource = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        file_name="detail.txt",
        file_label="DetailLabel",
        tags=["x", "y"],
        line_count=5,
        byte_size=50,
    )
    for endpoint in ["", "/edit"]:
        url = f"/api/v1/web/resources/{resource.id}{endpoint}"
        resp = await authenticated_async_client.get(url)
        assert resp.status_code == HTTPStatus.OK
        data = resp.json()
        assert data["file_label"] == "DetailLabel"
        assert data["tags"] == ["x", "y"]


@pytest.mark.asyncio
async def test_patch_update_resource_content_file_backed(
    authenticated_async_client: AsyncClient,
    minio_client: Minio,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    # Create file-backed resource
    resource = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        file_name="patchcontent.txt",
        line_count=3,
        byte_size=30,
        is_uploaded=True,
        download_url="s3://bucket/obj",
    )
    # Upload to MinIO
    bucket = settings.MINIO_BUCKET
    if not minio_client.bucket_exists(bucket):
        minio_client.make_bucket(bucket)
    minio_client.put_object(
        bucket, str(resource.id), io.BytesIO(b"one\ntwo\nthree\n"), length=12
    )
    url = f"/api/v1/web/resources/{resource.id}/content"
    new_content = "alpha\nbeta\ngamma"
    resp = await authenticated_async_client.patch(url, data={"content": new_content})
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # Confirm MinIO content updated
    obj = minio_client.get_object(bucket, str(resource.id))
    downloaded = obj.read().decode("utf-8")
    assert downloaded == new_content
    obj.close()


@pytest.mark.asyncio
async def test_patch_update_resource_content_ephemeral_forbidden(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    from sqlalchemy.ext.mutable import MutableDict

    resource = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.EPHEMERAL_WORD_LIST,
        file_name="ephemeral.txt",
        content=MutableDict({"lines": ["old1", "old2"]}),
        line_count=2,
        byte_size=10,
    )
    url = f"/api/v1/web/resources/{resource.id}/content"
    new_content = "foo\nbar\nbaz"
    resp = await authenticated_async_client.patch(url, data={"content": new_content})
    assert resp.status_code == HTTPStatus.FORBIDDEN


@pytest.mark.asyncio
async def test_patch_update_resource_content_forbidden(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    # Dynamic word list (forbidden)
    resource = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.DYNAMIC_WORD_LIST,
        file_name="dynamic.txt",
        line_count=2,
        byte_size=10,
    )
    url = f"/api/v1/web/resources/{resource.id}/content"
    resp = await authenticated_async_client.patch(url, data={"content": "foo\nbar"})
    assert resp.status_code == HTTPStatus.FORBIDDEN
    # Oversize (forbidden)
    resource2 = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        file_name="oversize.txt",
        line_count=10000,
        byte_size=10**7,
    )
    url2 = f"/api/v1/web/resources/{resource2.id}/content"
    resp2 = await authenticated_async_client.patch(url2, data={"content": "foo\nbar"})
    assert resp2.status_code == HTTPStatus.FORBIDDEN
    # Not editable with this endpoint
    resource3 = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.EPHEMERAL_RULE_LIST,
        file_name="noteditable.txt",
        line_count=2,
        byte_size=10,
    )
    url3 = f"/api/v1/web/resources/{resource3.id}/content"
    resp3 = await authenticated_async_client.patch(url3, data={"content": "foo\nbar"})
    assert resp3.status_code == HTTPStatus.FORBIDDEN
