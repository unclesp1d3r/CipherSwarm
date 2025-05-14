from uuid import UUID

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attack_resource_file import AttackResourceType
from tests.factories.attack_resource_file_factory import AttackResourceFileFactory


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
