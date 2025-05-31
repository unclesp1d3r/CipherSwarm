from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.tasks import crackable_uploads_tasks as tasks
from app.models.campaign import Campaign
from app.models.hash_item import HashItem
from app.models.hash_list import HashList
from app.models.hash_upload_task import HashUploadStatus
from app.models.raw_hash import RawHash
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.hash_type_factory import HashTypeFactory
from tests.factories.hash_upload_task_factory import HashUploadTaskFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.raw_hash_factory import RawHashFactory
from tests.factories.upload_resource_file_factory import UploadResourceFileFactory
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_load_upload_task_found(
    db_session: AsyncSession,
    user_factory: UserFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
) -> None:
    user = await user_factory.create_async()
    task = await hash_upload_task_factory.create_async(user_id=user.id)
    loaded = await tasks.load_upload_task(task.id, db_session)
    assert loaded.id == task.id


@pytest.mark.asyncio
async def test_load_upload_task_not_found(db_session: AsyncSession) -> None:
    with pytest.raises(ValueError):
        await tasks.load_upload_task(999999, db_session)


@pytest.mark.asyncio
async def test_load_upload_resource_file_found(
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    upload_resource_file_factory: UploadResourceFileFactory,
) -> None:
    project = await project_factory.create_async()
    resource = await upload_resource_file_factory.create_async(project_id=project.id)
    loaded = await tasks.load_upload_resource_file(resource.file_name, db_session)
    assert loaded.id == resource.id


@pytest.mark.asyncio
async def test_load_upload_resource_file_not_found(db_session: AsyncSession) -> None:
    with pytest.raises(ValueError):
        await tasks.load_upload_resource_file("notfound.txt", db_session)


@pytest.mark.asyncio
@patch("app.core.tasks.crackable_uploads_tasks.get_storage_service")
async def test_download_upload_file_mocks_minio(
    mock_get_storage_service: MagicMock,
) -> None:
    resource = UploadResourceFileFactory.build()
    mock_service = MagicMock()
    mock_service.bucket = "uploads"
    mock_obj = MagicMock()
    mock_obj.stream.return_value = [b"hash1\n", b"hash2\n"]
    mock_service.client.get_object.return_value = mock_obj
    mock_get_storage_service.return_value = mock_service
    path = await tasks.download_upload_file(resource)
    # Should return a Path and file should exist
    assert isinstance(path, Path)
    assert path.exists()
    with path.open("rb") as f:
        content = f.read()
        assert b"hash1" in content
    path.unlink()


@pytest.mark.asyncio
async def test_update_task_status_running(
    db_session: AsyncSession,
    user_factory: UserFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
) -> None:
    user = await user_factory.create_async()
    task = await hash_upload_task_factory.create_async(
        status=HashUploadStatus.PENDING, user_id=user.id
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    await tasks.update_task_status_running(task, db_session)
    assert task.status == HashUploadStatus.RUNNING
    assert task.started_at is not None


@patch("app.core.tasks.crackable_uploads_tasks.dispatch_extract_hashes")
def test_extract_hashes_with_plugin_success(
    mock_dispatch: MagicMock,
    raw_hash_factory: RawHashFactory,
) -> None:
    mock_dispatch.return_value = [raw_hash_factory.build()]
    tmp_path = Path("/tmp/fakefile")
    ext = "shadow"
    result = tasks.extract_hashes_with_plugin(tmp_path, ext, 1)
    assert isinstance(result, list)
    assert isinstance(result[0], RawHash)


@patch(
    "app.core.tasks.crackable_uploads_tasks.dispatch_extract_hashes",
    side_effect=Exception("fail"),
)
def test_extract_hashes_with_plugin_error(mock_dispatch: MagicMock) -> None:
    tmp_path = Path("/tmp/fakefile")
    ext = "shadow"

    with pytest.raises(Exception):  # noqa: B017
        tasks.extract_hashes_with_plugin(tmp_path, ext, 1)


@pytest.mark.asyncio
async def test_insert_raw_hashes(
    db_session: AsyncSession,
    hash_type_factory: HashTypeFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
    user_factory: UserFactory,
    raw_hash_factory: RawHashFactory,
) -> None:
    hash_type = await hash_type_factory.create_async()
    upload_task = await hash_upload_task_factory.create_async(
        user_id=(await user_factory.create_async()).id
    )
    raw_hashes = [
        raw_hash_factory.build(
            hash_type_id=hash_type.id, upload_task_id=upload_task.id
        ),
        raw_hash_factory.build(
            hash_type_id=hash_type.id, upload_task_id=upload_task.id
        ),
    ]
    await tasks.insert_raw_hashes(raw_hashes, db_session)
    # No exception means success


@pytest.mark.asyncio
async def test_create_hashlist_and_campaign(
    db_session: AsyncSession,
    user_factory: UserFactory,
    project_factory: ProjectFactory,
    hash_type_factory: HashTypeFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
    upload_resource_file_factory: UploadResourceFileFactory,
    raw_hash_factory: RawHashFactory,
) -> None:
    user = await user_factory.create_async()
    project = await project_factory.create_async()
    task = await hash_upload_task_factory.create_async(user_id=user.id)
    resource = await upload_resource_file_factory.create_async(project_id=project.id)
    hash_type = await hash_type_factory.create_async()
    raw_hashes = [
        raw_hash_factory.build(hash_type_id=hash_type.id, upload_task_id=task.id)
    ]
    hash_list, campaign = await tasks.create_hashlist_and_campaign(
        task, resource, raw_hashes, db_session
    )
    assert isinstance(hash_list, HashList)
    assert isinstance(campaign, Campaign)
    assert task.hash_list_id == hash_list.id
    assert task.campaign_id == campaign.id


@pytest.mark.asyncio
async def test_parse_and_insert_hashitems(
    db_session: AsyncSession,
    user_factory: UserFactory,
    project_factory: ProjectFactory,
    hash_type_factory: HashTypeFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
    hash_list_factory: HashListFactory,
    raw_hash_factory: RawHashFactory,
) -> None:
    user = await user_factory.create_async()
    project = await project_factory.create_async()
    task = await hash_upload_task_factory.create_async(user_id=user.id)
    hash_type = await hash_type_factory.create_async()
    hash_list = await hash_list_factory.create_async(
        project_id=project.id, hash_type_id=hash_type.id
    )
    raw_hashes = [
        raw_hash_factory.build(hash_type_id=hash_type.id, upload_task_id=task.id)
    ]
    error_count = await tasks.parse_and_insert_hashitems(
        task, raw_hashes, hash_list, db_session
    )
    assert isinstance(error_count, int)


@pytest.mark.asyncio
async def test_update_status_fields(
    db_session: AsyncSession,
    user_factory: UserFactory,
    project_factory: ProjectFactory,
    hash_type_factory: HashTypeFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
    hash_list_factory: HashListFactory,
    campaign_factory: CampaignFactory,
) -> None:
    # COMPLETED case
    user = await user_factory.create_async()
    project = await project_factory.create_async()
    hash_type = await hash_type_factory.create_async()
    task1 = await hash_upload_task_factory.create_async(user_id=user.id)
    hash_list1 = await hash_list_factory.create_async(
        project_id=project.id, hash_type_id=hash_type.id
    )
    campaign1 = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list1.id
    )
    hash_items = [HashItem()]
    await tasks.update_status_fields(
        task1, hash_list1, campaign1, 0, hash_items, db_session
    )
    assert task1.status == HashUploadStatus.COMPLETED

    # PARTIAL_FAILURE case
    task2 = await hash_upload_task_factory.create_async(user_id=user.id)
    hash_list2 = await hash_list_factory.create_async(
        project_id=project.id, hash_type_id=hash_type.id
    )
    campaign2 = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list2.id
    )
    await tasks.update_status_fields(
        task2, hash_list2, campaign2, 1, hash_items, db_session
    )
    assert task2.status == HashUploadStatus.PARTIAL_FAILURE

    # FAILED case
    task3 = await hash_upload_task_factory.create_async(user_id=user.id)
    hash_list3 = await hash_list_factory.create_async(
        project_id=project.id, hash_type_id=hash_type.id
    )
    campaign3 = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list3.id
    )
    await tasks.update_status_fields(task3, hash_list3, campaign3, 1, [], db_session)
    assert task3.status == HashUploadStatus.FAILED
