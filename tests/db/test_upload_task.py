from datetime import UTC, datetime

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.hash_type import HashType
from app.models.hash_upload_task import (
    HashUploadStatus,
    HashUploadTask,
)
from app.models.raw_hash import RawHash
from app.models.upload_error_entry import UploadErrorEntry
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.hash_upload_task_factory import (
    HashUploadTaskFactory,
    UploadErrorEntryFactory,
)
from tests.factories.project_factory import ProjectFactory
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_create_upload_task(
    project_factory: ProjectFactory,
    user_factory: UserFactory,
    hash_list_factory: HashListFactory,
    campaign_factory: CampaignFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
) -> None:
    project = await project_factory.create_async()
    user = await user_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )

    task = await hash_upload_task_factory.create_async(
        user_id=user.id,
        filename="shadow.txt",
        status=HashUploadStatus.PENDING,
        started_at=datetime.now(UTC),
        hash_list_id=hash_list.id,
        campaign_id=campaign.id,
    )
    assert task.id is not None
    assert task.status == HashUploadStatus.PENDING
    assert task.user_id == user.id
    assert task.hash_list_id == hash_list.id
    assert task.campaign_id == campaign.id


@pytest.mark.asyncio
async def test_upload_error_entry(
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    user_factory: UserFactory,
    hash_list_factory: HashListFactory,
    campaign_factory: CampaignFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
    upload_error_entry_factory: UploadErrorEntryFactory,
) -> None:
    project = await project_factory.create_async()
    user = await user_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )

    task = await hash_upload_task_factory.create_async(
        user_id=user.id,
        filename="shadow.txt",
        hash_list_id=hash_list.id,
        campaign_id=campaign.id,
    )
    err = await upload_error_entry_factory.create_async(
        upload_id=task.id,
        line_number=42,
        raw_line="badline",
        error_message="Parse error",
    )
    db_session.add(err)
    await db_session.commit()
    await db_session.refresh(err)
    assert err.id is not None
    assert err.upload_id == task.id
    assert err.line_number == 42
    assert err.raw_line == "badline"
    assert err.error_message == "Parse error"
    # Relationship
    result = await db_session.execute(
        select(HashUploadTask)
        .options(selectinload(HashUploadTask.errors))
        .where(HashUploadTask.id == task.id)
    )
    loaded_task = result.scalar_one()
    assert err.upload_task.id == task.id
    assert loaded_task.errors[0].id == err.id


@pytest.mark.asyncio
async def test_cascade_delete_upload_task_deletes_errors(
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    user_factory: UserFactory,
    hash_list_factory: HashListFactory,
    campaign_factory: CampaignFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
    upload_error_entry_factory: UploadErrorEntryFactory,
) -> None:
    project = await project_factory.create_async()
    user = await user_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )

    task = await hash_upload_task_factory.create_async(
        user_id=user.id,
        filename="shadow.txt",
        hash_list_id=hash_list.id,
        campaign_id=campaign.id,
    )
    await upload_error_entry_factory.create_async(
        upload_id=task.id,
        line_number=1,
        raw_line="bad",
        error_message="fail",
    )
    task_id = task.id
    await db_session.delete(task)
    await db_session.commit()
    result = await db_session.execute(
        select(UploadErrorEntry).where(UploadErrorEntry.upload_id == task_id)
    )
    found = result.scalars().all()
    assert found == []


@pytest.mark.asyncio
async def test_create_raw_hash(
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    user_factory: UserFactory,
    hash_list_factory: HashListFactory,
    campaign_factory: CampaignFactory,
    hash_upload_task_factory: HashUploadTaskFactory,
    upload_error_entry_factory: UploadErrorEntryFactory,
) -> None:
    project = await project_factory.create_async()
    user = await user_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    task = await hash_upload_task_factory.create_async(
        user_id=user.id,
        filename="shadow.txt",
        hash_list_id=hash_list.id,
        campaign_id=campaign.id,
    )
    # Create or get a hash type
    result = await db_session.execute(
        select(HashType).where(HashType.name == "sha512crypt")
    )
    hash_type = result.scalar_one_or_none()
    if not hash_type:
        hash_type = HashType(
            id=1800,
            name="sha512crypt",
            description="SHA-512 Crypt",
            john_mode="sha512crypt",
        )  # Unique IDs have to be manually set to the hashcat mode
        db_session.add(hash_type)
        await db_session.commit()
        await db_session.refresh(hash_type)
    # Create a raw hash
    raw_hash = RawHash(
        hash="deadbeef",
        hash_type_id=hash_type.id,
        username="alice",
        meta={"source": "test"},
        line_number=1,
        upload_task_id=task.id,
    )
    db_session.add(raw_hash)
    await db_session.commit()
    await db_session.refresh(raw_hash)
    # Eagerly load relationships to avoid MissingGreenlet
    result = await db_session.execute(
        select(RawHash)
        .options(selectinload(RawHash.upload_task), selectinload(RawHash.hash_type))
        .where(RawHash.id == raw_hash.id)
    )
    raw_hash_loaded = result.scalar_one()
    assert raw_hash_loaded.id is not None
    assert raw_hash_loaded.hash == "deadbeef"
    assert raw_hash_loaded.hash_type_id == hash_type.id
    assert raw_hash_loaded.username == "alice"
    assert raw_hash_loaded.meta == {"source": "test"}
    assert raw_hash_loaded.line_number == 1
    assert raw_hash_loaded.upload_task_id == task.id
    # Relationship
    assert raw_hash_loaded.upload_task.id == task.id
    assert raw_hash_loaded.hash_type.id == hash_type.id
    # Test error entry relationship
    error = await upload_error_entry_factory.create_async(
        upload_id=task.id,
        line_number=1,
        raw_line="badline",
        error_message="Parse error",
    )
    raw_hash.upload_error_entry_id = error.id
    db_session.add(raw_hash)
    await db_session.commit()
    await db_session.refresh(raw_hash)
    # Eagerly load all relationships to avoid MissingGreenlet
    result = await db_session.execute(
        select(RawHash)
        .options(
            selectinload(RawHash.upload_task),
            selectinload(RawHash.hash_type),
            selectinload(RawHash.upload_error_entry),
        )
        .where(RawHash.id == raw_hash.id)
    )
    raw_hash_loaded = result.scalar_one()
    # Reload error with relationship
    result = await db_session.execute(
        select(UploadErrorEntry)
        .options(selectinload(UploadErrorEntry.raw_hash))
        .where(UploadErrorEntry.id == error.id)
    )
    error_loaded = result.scalar_one()
    assert raw_hash_loaded.upload_error_entry.id == error_loaded.id
    assert error_loaded.raw_hash.id == raw_hash_loaded.id
