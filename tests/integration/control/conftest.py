import uuid

import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession

from tests.utils.test_helpers import create_user_with_api_key_and_project_access


@pytest_asyncio.fixture
async def api_user_with_project(
    db_session: AsyncSession,
) -> tuple[uuid.UUID, int, str]:
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Test User", project_name="Test Project"
    )
    return user_id, project_id, api_key

