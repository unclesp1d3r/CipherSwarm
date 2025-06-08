import pytest
from httpx import AsyncClient, codes
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.campaign import CampaignState
from app.models.hash_upload_task import HashUploadStatus
from app.models.project import ProjectUserAssociation, ProjectUserRole
from app.models.user import User
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.hash_upload_task_factory import HashUploadTaskFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.raw_hash_factory import RawHashFactory
from tests.factories.upload_error_entry_factory import UploadErrorEntryFactory
from tests.factories.upload_resource_file_factory import UploadResourceFileFactory
from tests.utils.hash_type_utils import get_or_create_hash_type


@pytest.mark.asyncio
async def test_delete_upload_success(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    upload_resource_file_factory: UploadResourceFileFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
    hash_list_factory: HashListFactory,
    campaign_factory: CampaignFactory,
    raw_hash_factory: RawHashFactory,
    upload_error_entry_factory: UploadErrorEntryFactory,
) -> None:
    """Test successful deletion of an upload task and all associated data."""
    client, user = authenticated_user_client
    project = await project_factory.create_async()

    # Create project association
    association = ProjectUserAssociation(
        user_id=user.id, project_id=project.id, role=ProjectUserRole.member
    )
    db_session.add(association)
    await db_session.commit()

    # Create hash type
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Create upload resource file
    resource = await upload_resource_file_factory.create_async(
        project_id=project.id, file_name="test_upload.txt"
    )

    # Create hash list and campaign (unavailable)
    hash_list = await hash_list_factory.create_async(
        project_id=project.id, hash_type_id=hash_type.id, is_unavailable=True
    )

    campaign = await campaign_factory.create_async(
        project_id=project.id,
        hash_list_id=hash_list.id,
        state=CampaignState.DRAFT,
        is_unavailable=True,
    )

    # Create upload task with campaign/hash_list linked
    upload_task = await hash_upload_task_factory.create_async(
        filename=resource.file_name,
        user_id=user.id,
        status=HashUploadStatus.COMPLETED,
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
    )

    # Create associated raw hashes and errors
    await raw_hash_factory.create_async(
        upload_task_id=upload_task.id, hash_type_id=hash_type.id
    )

    await upload_error_entry_factory.create_async(upload_id=upload_task.id)

    # Delete the upload
    response = await client.delete(f"/api/v1/web/uploads/{upload_task.id}")

    assert response.status_code == codes.NO_CONTENT


@pytest.mark.asyncio
async def test_delete_upload_unauthorized_user(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    upload_resource_file_factory: UploadResourceFileFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
) -> None:
    """Test that users can't delete uploads from projects they're not associated with."""
    client, user = authenticated_user_client
    other_project = await project_factory.create_async()

    # Create upload task in other project (no association for user)
    resource = await upload_resource_file_factory.create_async(
        project_id=other_project.id, file_name="test_upload.txt"
    )

    upload_task = await hash_upload_task_factory.create_async(
        filename=resource.file_name, user_id=user.id, status=HashUploadStatus.COMPLETED
    )

    # Attempt to delete should fail
    response = await client.delete(f"/api/v1/web/uploads/{upload_task.id}")

    assert response.status_code == codes.FORBIDDEN
    data = response.json()
    assert "not authorized" in data["detail"].lower()


@pytest.mark.asyncio
async def test_delete_upload_launched_campaign(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    upload_resource_file_factory: UploadResourceFileFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
    hash_list_factory: HashListFactory,
    campaign_factory: CampaignFactory,
) -> None:
    """Test that uploads can't be deleted if campaign/hash_list have been launched."""
    client, user = authenticated_user_client
    project = await project_factory.create_async()

    # Create project association
    association = ProjectUserAssociation(
        user_id=user.id, project_id=project.id, role=ProjectUserRole.member
    )
    db_session.add(association)
    await db_session.commit()

    # Create hash type
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Create upload resource file
    resource = await upload_resource_file_factory.create_async(
        project_id=project.id, file_name="test_upload.txt"
    )

    # Create hash list and campaign (AVAILABLE - launched)
    hash_list = await hash_list_factory.create_async(
        project_id=project.id,
        hash_type_id=hash_type.id,
        is_unavailable=False,  # This makes it launched
    )

    campaign = await campaign_factory.create_async(
        project_id=project.id,
        hash_list_id=hash_list.id,
        state=CampaignState.ACTIVE,
        is_unavailable=False,  # This makes it launched
    )

    # Create upload task with launched campaign/hash_list
    upload_task = await hash_upload_task_factory.create_async(
        filename=resource.file_name,
        user_id=user.id,
        status=HashUploadStatus.COMPLETED,
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
    )

    # Attempt to delete should fail
    response = await client.delete(f"/api/v1/web/uploads/{upload_task.id}")

    assert response.status_code == codes.CONFLICT
    data = response.json()
    assert "campaign has been launched" in data["detail"].lower()


@pytest.mark.asyncio
async def test_delete_upload_not_found(
    authenticated_user_client: tuple[AsyncClient, User],
) -> None:
    """Test deletion of non-existent upload task."""
    client, user = authenticated_user_client

    response = await client.delete("/api/v1/web/uploads/99999")

    assert response.status_code == codes.NOT_FOUND
    data = response.json()
    assert "not found" in data["detail"].lower()


@pytest.mark.asyncio
async def test_delete_upload_processing_in_progress(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    upload_resource_file_factory: UploadResourceFileFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
) -> None:
    """Test deletion of upload task that is still processing."""
    client, user = authenticated_user_client
    project = await project_factory.create_async()

    # Create project association
    association = ProjectUserAssociation(
        user_id=user.id, project_id=project.id, role=ProjectUserRole.member
    )
    db_session.add(association)
    await db_session.commit()

    # Create upload resource file
    resource = await upload_resource_file_factory.create_async(
        project_id=project.id, file_name="test_upload.txt"
    )

    # Create upload task still in progress
    upload_task = await hash_upload_task_factory.create_async(
        filename=resource.file_name,
        user_id=user.id,
        status=HashUploadStatus.RUNNING,  # Still processing
    )

    # Delete should work even while processing
    response = await client.delete(f"/api/v1/web/uploads/{upload_task.id}")

    assert response.status_code == codes.NO_CONTENT
