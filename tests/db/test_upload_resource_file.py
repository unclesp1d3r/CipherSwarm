from uuid import UUID

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from tests.factories.upload_resource_file_factory import UploadResourceFileFactory


@pytest.mark.asyncio
async def test_upload_resource_file_guid(
    db_session: AsyncSession,
    upload_resource_file_factory: UploadResourceFileFactory,
) -> None:
    resource1 = await upload_resource_file_factory.create_async()
    resource2 = await upload_resource_file_factory.create_async()
    assert isinstance(resource1.guid, UUID)
    assert isinstance(resource2.guid, UUID)
    assert resource1.guid != resource2.guid
    fetched = await db_session.get(resource1.__class__, resource1.id)
    assert fetched is not None
    assert fetched.guid == resource1.guid


@pytest.mark.asyncio
async def test_upload_resource_file_metadata_fields(
    db_session: AsyncSession,
    upload_resource_file_factory: UploadResourceFileFactory,
) -> None:
    resource = await upload_resource_file_factory.create_async()
    assert resource.line_encoding == "utf-8"
    assert resource.source == "upload"
    assert resource.line_count == 10
    assert resource.byte_size == 100
    resource2 = await upload_resource_file_factory.create_async(
        line_encoding="ascii",
        source="generated",
        line_count=42,
        byte_size=2048,
    )
    assert resource2.line_encoding == "ascii"
    assert resource2.source == "generated"
    assert resource2.line_count == 42
    assert resource2.byte_size == 2048
    fetched = await db_session.get(resource2.__class__, resource2.id)
    assert fetched is not None
    assert fetched.line_encoding == "ascii"
    assert fetched.source == "generated"
    assert fetched.line_count == 42
    assert fetched.byte_size == 2048


@pytest.mark.asyncio
async def test_upload_resource_file_is_uploaded(
    db_session: AsyncSession,
    upload_resource_file_factory: UploadResourceFileFactory,
) -> None:
    resource = await upload_resource_file_factory.create_async()
    assert resource.is_uploaded is False
    resource2 = await upload_resource_file_factory.create_async(is_uploaded=True)
    assert resource2.is_uploaded is True
    fetched = await db_session.get(resource2.__class__, resource2.id)
    assert fetched is not None
    assert fetched.is_uploaded is True
