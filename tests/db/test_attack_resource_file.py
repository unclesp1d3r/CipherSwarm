from uuid import UUID

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attack import AttackMode
from app.models.attack_resource_file import AttackResourceType
from tests.factories.attack_resource_file_factory import AttackResourceFileFactory

DEFAULT_LINE_COUNT = 10
DEFAULT_BYTE_SIZE = 100
EXPLICIT_LINE_COUNT = 42
EXPLICIT_BYTE_SIZE = 2048


@pytest.mark.asyncio
async def test_attack_resource_file_guid(db_session: AsyncSession) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    resource1 = await AttackResourceFileFactory.create_async()
    resource2 = await AttackResourceFileFactory.create_async()
    assert isinstance(resource1.guid, UUID)
    assert isinstance(resource2.guid, UUID)
    assert resource1.guid != resource2.guid
    # Ensure guid is persisted
    fetched = await db_session.get(resource1.__class__, resource1.id)
    assert fetched is not None
    assert fetched.guid == resource1.guid


@pytest.mark.asyncio
async def test_attack_resource_file_resource_type(db_session: AsyncSession) -> None:
    from tests.factories.attack_resource_file_factory import AttackResourceFileFactory

    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    # Default should be WORD_LIST
    resource = await AttackResourceFileFactory.create_async()
    assert resource.resource_type == AttackResourceType.WORD_LIST
    # Can set to MASK_LIST
    resource2 = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.MASK_LIST
    )
    assert resource2.resource_type == AttackResourceType.MASK_LIST
    # Persisted in DB
    fetched = await db_session.get(resource2.__class__, resource2.id)
    assert fetched is not None
    assert fetched.resource_type == AttackResourceType.MASK_LIST


@pytest.mark.asyncio
async def test_attack_resource_file_metadata_fields(db_session: AsyncSession) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    resource = await AttackResourceFileFactory.create_async()
    assert resource.line_format == "freeform"
    assert resource.line_encoding == "utf-8"
    assert resource.used_for_modes == [AttackMode.DICTIONARY]
    assert resource.source == "upload"
    assert resource.line_count == DEFAULT_LINE_COUNT
    assert resource.byte_size == DEFAULT_BYTE_SIZE
    # Test explicit values
    resource2 = await AttackResourceFileFactory.create_async(
        line_format="mask",
        line_encoding="ascii",
        used_for_modes=[AttackMode.MASK],
        source="generated",
        line_count=EXPLICIT_LINE_COUNT,
        byte_size=EXPLICIT_BYTE_SIZE,
    )
    assert resource2.line_format == "mask"
    assert resource2.line_encoding == "ascii"
    assert resource2.used_for_modes == [AttackMode.MASK]
    assert resource2.source == "generated"
    assert resource2.line_count == EXPLICIT_LINE_COUNT
    assert resource2.byte_size == EXPLICIT_BYTE_SIZE
    # Persisted in DB
    fetched = await db_session.get(resource2.__class__, resource2.id)
    assert fetched is not None
    assert fetched.line_format == "mask"
    assert fetched.line_encoding == "ascii"
    assert fetched.used_for_modes == [AttackMode.MASK]
    assert fetched.source == "generated"
    assert fetched.line_count == EXPLICIT_LINE_COUNT
    assert fetched.byte_size == EXPLICIT_BYTE_SIZE


@pytest.mark.asyncio
async def test_attack_resource_file_is_uploaded(db_session: AsyncSession) -> None:
    AttackResourceFileFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    # Default should be False
    resource = await AttackResourceFileFactory.create_async()
    assert resource.is_uploaded is False
    # Can set to True
    resource2 = await AttackResourceFileFactory.create_async(is_uploaded=True)
    assert resource2.is_uploaded is True
    # Persisted in DB
    fetched = await db_session.get(resource2.__class__, resource2.id)
    assert fetched is not None
    assert fetched.is_uploaded is True
