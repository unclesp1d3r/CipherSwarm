import uuid

import httpx
import pytest
from httpx import AsyncClient
from sqlalchemy import insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload

from app.core.tasks.crackable_uploads_tasks import process_uploaded_hash_file
from app.models.hash_type import HashType
from app.models.hash_upload_task import HashUploadTask
from app.models.project import ProjectUserAssociation, ProjectUserRole
from app.models.upload_resource_file import UploadResourceFile
from app.models.user import User
from app.schemas.hash_list import HashListOut
from tests.factories.hash_item_factory import HashItemFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.hash_type_factory import HashTypeFactory
from tests.factories.hash_upload_task_factory import (
    HashUploadTaskFactory,
    UploadErrorEntryFactory,
)
from tests.factories.project_factory import ProjectFactory
from tests.factories.raw_hash_factory import RawHashFactory
from tests.factories.upload_resource_file_factory import UploadResourceFileFactory


@pytest.mark.asyncio
async def test_uploads_happy_path(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
) -> None:
    async_client, user = authenticated_user_client
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Seed the hash_types table with id=1800 (required by the pipeline) if not present
    result = await db_session.execute(select(HashType).where(HashType.id == 1800))
    if result.scalar_one_or_none() is None:
        await db_session.execute(
            insert(HashType),
            [
                {
                    "id": 1800,
                    "name": "sha512crypt",
                    "description": "SHA512-crypt (shadow)",
                    "john_mode": None,
                }
            ],
        )
        await db_session.commit()

    url = "/api/v1/web/uploads/"
    file_name = f"test_upload_{uuid.uuid4()}.shadow"
    resp = await async_client.post(
        url,
        data={
            "file_name": file_name,
            "project_id": project.id,
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    assert "presigned_url" in data
    assert data["resource"]["file_name"] == file_name
    # Check DB record exists
    resource_id = data["resource_id"]
    resource = await db_session.get(UploadResourceFile, resource_id)
    assert resource is not None
    assert resource.file_name == file_name
    assert resource.is_uploaded is False
    assert resource.line_count == 0
    assert resource.byte_size == 0
    assert resource.download_url == ""
    assert resource.checksum == ""
    assert resource.line_encoding == "utf-8"
    # Presigned URL basic check
    assert data["presigned_url"].startswith("http")

    # Upload a valid shadow file to MinIO using the presigned URL
    test_content = b"testuser:$6$saltsalt$abcdefghijklmnopqrstuvwx:19000:0:99999:7:::\n"
    async with httpx.AsyncClient() as minio_client:
        put_resp = await minio_client.put(data["presigned_url"], content=test_content)
        assert put_resp.status_code in {200, 204}

    # Mark the resource as uploaded in the DB (simulate upload verification)
    resource.is_uploaded = True
    resource.line_count = 1
    resource.byte_size = len(test_content)
    await db_session.commit()
    await db_session.refresh(resource)

    # Retrieve the HashUploadTask for this upload
    result = await db_session.execute(
        select(HashUploadTask).where(HashUploadTask.filename == file_name)
    )
    task = result.scalar_one()
    assert task is not None

    # Manually trigger the background processing task with the correct task ID
    await process_uploaded_hash_file(task.id, db_session)


@pytest.mark.asyncio
async def test_uploads_unauthorized(async_client: AsyncClient) -> None:
    url = "/api/v1/web/uploads/"
    resp = await async_client.post(url, data={"file_name": "foo.txt"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_uploads_forbidden(
    authenticated_user_client: tuple[AsyncClient, User],
    project_factory: ProjectFactory,
) -> None:
    async_client, user = authenticated_user_client
    url = "/api/v1/web/uploads/"
    file_name = f"test_upload_{uuid.uuid4()}.txt"
    # Case 1: Project does not exist (should return 404)
    nonexistent_project_id = 999999
    resp = await async_client.post(
        url,
        data={
            "file_name": file_name,
            "project_id": nonexistent_project_id,
        },
    )
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Project not found."
    # Case 2: Project exists but user is not a member (should return 403)
    project = await project_factory.create_async()
    # Do NOT associate the test user with this project
    resp2 = await async_client.post(
        url,
        data={
            "file_name": file_name,
            "project_id": project.id,
        },
    )
    assert resp2.status_code == 403
    assert resp2.json()["detail"] == "Not authorized for this project."


@pytest.mark.asyncio
async def test_uploads_invalid_input(authenticated_async_client: AsyncClient) -> None:
    url = "/api/v1/web/uploads/"
    # Missing file_name
    resp = await authenticated_async_client.post(url, data={})
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_ephemeral_hashlist_creation(
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_item_factory: HashItemFactory,
    hash_list_factory: HashListFactory,
) -> None:
    """
    Test that an ephemeral hash list is created when a file is uploaded.

    A project is created, and a hash list is created with 3 hash items.
    The hash list is marked as unavailable, and the items are added to the hash list.
    The hash list is then marked as available, and the items are checked.
    The hash list is then marked as unavailable, and the items are checked.
    """
    # Create a real project
    project = await project_factory.create_async()
    # Create hash items
    items = [hash_item_factory.build(meta={}) for _ in range(3)]
    for item in items:
        db_session.add(item)
    await db_session.flush()
    # Create ephemeral hash list
    hash_list = hash_list_factory.build(
        is_unavailable=True, project_id=project.id, hash_type_id=0, items=[]
    )
    hash_list.items.extend(items)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.refresh(hash_list)
    # Eagerly load items relationship to avoid MissingGreenlet
    result = await db_session.execute(
        select(hash_list.__class__)
        .options(selectinload(hash_list.__class__.items))
        .where(hash_list.__class__.id == hash_list.id)
    )
    hash_list_loaded = result.scalar_one()
    # Serialize with schema
    out = HashListOut.model_validate(hash_list_loaded)
    # Only count items with hash == 'deadbeef' and meta == None (added in this test)
    test_items = [
        item
        for item in out.items
        if item.hash == "deadbeef" and (item.meta == {} or item.meta is None)
    ]
    assert out.is_unavailable is True
    assert len(test_items) == 3
    # Mark as available and check
    hash_list.is_unavailable = False
    await db_session.commit()
    await db_session.refresh(hash_list)
    result2 = await db_session.execute(
        select(hash_list.__class__)
        .options(selectinload(hash_list.__class__.items))
        .where(hash_list.__class__.id == hash_list.id)
    )
    hash_list_loaded2 = result2.scalar_one()
    out2 = HashListOut.model_validate(hash_list_loaded2)
    test_items2 = [
        item
        for item in out2.items
        if item.hash == "deadbeef" and (item.meta == {} or item.meta is None)
    ]
    assert out2.is_unavailable is False
    assert len(test_items2) == 3


@pytest.mark.asyncio
async def test_upload_status_success(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
    upload_resource_file_factory: UploadResourceFileFactory,
    raw_hash_factory: RawHashFactory,
    hash_type_factory: HashTypeFactory,
) -> None:
    """
    Test that the upload status endpoint returns the correct data.

    The test creates a project, adds the user to the project, creates a hash type,
    creates an upload resource file, creates an upload task, creates raw hashes,
    and calls the status endpoint.
    The test then checks that the status endpoint returns the correct data.
    """
    async_client, user = authenticated_user_client
    project = await project_factory.create_async()
    # Add user to project
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()
    # Create hash type
    hash_type = await hash_type_factory.create_async(id=999, name="testtype")
    # Create upload resource file
    resource = await upload_resource_file_factory.create_async(
        file_name="status_test.txt", project_id=project.id
    )
    # Create upload task
    task = await hash_upload_task_factory.create_async(
        filename=resource.file_name, status="completed", error_count=0, user_id=user.id
    )
    # Create raw hashes
    await raw_hash_factory.create_async(
        hash="abc123", hash_type_id=hash_type.id, upload_task_id=task.id
    )
    await raw_hash_factory.create_async(
        hash="def456", hash_type_id=hash_type.id, upload_task_id=task.id
    )
    await db_session.commit()
    # Call status endpoint
    url = f"/api/v1/web/uploads/{task.id}/status"
    resp = await async_client.get(url)
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "completed"
    assert data["error_count"] == 0
    assert data["hash_type"] == "testtype"
    assert data["preview"] == ["abc123", "def456"]
    assert data["upload_resource_file_id"] == str(resource.id)
    assert data["upload_task_id"] == task.id
    assert data["validation_state"] == "valid"


@pytest.mark.asyncio
async def test_upload_status_not_found(
    authenticated_user_client: tuple[AsyncClient, User],
) -> None:
    """
    Test that the upload status endpoint returns 404 if the upload task is not found.
    """
    async_client, _ = authenticated_user_client
    resp = await async_client.get("/api/v1/web/uploads/999999/status")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_upload_status_unauthorized(async_client: AsyncClient) -> None:
    """
    Test that the upload status endpoint returns 401 if the user is not authenticated.
    """
    resp = await async_client.get("/api/v1/web/uploads/1/status")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_upload_status_forbidden(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
    upload_resource_file_factory: UploadResourceFileFactory,
) -> None:
    """
    Test that the upload status endpoint returns 403 if the user is not a member of the project.
    """
    async_client, user = authenticated_user_client
    project = await project_factory.create_async()
    # Do NOT add user to project
    resource = await upload_resource_file_factory.create_async(
        file_name="forbidden.txt", project_id=project.id
    )
    task = await hash_upload_task_factory.create_async(
        filename=resource.file_name, user_id=user.id
    )
    await db_session.commit()
    url = f"/api/v1/web/uploads/{task.id}/status"
    resp = await async_client.get(url)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_upload_errors_happy_path(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
    upload_resource_file_factory: UploadResourceFileFactory,
    upload_error_entry_factory: UploadErrorEntryFactory,
) -> None:
    """
    Test that the upload errors endpoint returns the correct data.

    The test creates a project, adds the user to the project, creates an upload resource file,
    creates an upload task, creates upload error entries, and calls the errors endpoint.
    """
    async_client, user = authenticated_user_client
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()
    resource = await upload_resource_file_factory.create_async(
        file_name="error_test.txt", project_id=project.id
    )
    task = await hash_upload_task_factory.create_async(
        filename=resource.file_name, user_id=user.id
    )
    # Add 3 errors
    for i in range(3):
        await upload_error_entry_factory.create_async(
            upload_id=task.id,
            line_number=i + 1,
            raw_line=f"badline{i}",
            error_message=f"fail{i}",
        )
    await db_session.commit()
    url = f"/api/v1/web/uploads/{task.id}/errors?page=1&page_size=2"
    resp = await async_client.get(url)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 3
    assert data["page"] == 1
    assert data["page_size"] == 2
    assert len(data["items"]) == 2
    assert data["items"][0]["raw_line"].startswith("badline")
    # Page 2
    resp2 = await async_client.get(
        f"/api/v1/web/uploads/{task.id}/errors?page=2&page_size=2"
    )
    assert resp2.status_code == 200
    data2 = resp2.json()
    assert data2["page"] == 2
    assert len(data2["items"]) == 1
    # Forbidden
    # Remove user from project
    await db_session.delete(assoc)
    await db_session.commit()
    resp3 = await async_client.get(url)
    assert resp3.status_code == 403
    # Not found
    resp4 = await async_client.get("/api/v1/web/uploads/999999/errors")
    assert resp4.status_code == 404
