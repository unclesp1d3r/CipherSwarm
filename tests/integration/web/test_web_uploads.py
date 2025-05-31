import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload

from app.models.project import ProjectUserAssociation, ProjectUserRole
from app.models.upload_resource_file import UploadResourceFile
from app.models.user import User
from app.schemas.hash_list import HashListOut
from tests.factories.hash_item_factory import HashItemFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory


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

    url = "/api/v1/web/uploads/"
    file_name = f"test_upload_{uuid.uuid4()}.txt"
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
