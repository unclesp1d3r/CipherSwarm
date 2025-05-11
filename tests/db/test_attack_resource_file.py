from uuid import UUID

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

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
