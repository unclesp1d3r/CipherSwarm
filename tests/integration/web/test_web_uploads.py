import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.project import ProjectUserAssociation, ProjectUserRole
from app.models.upload_resource_file import UploadResourceFile
from app.models.user import User
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
