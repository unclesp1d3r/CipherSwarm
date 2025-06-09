"""Test helper utilities for common patterns across the test suite."""

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.user_service import generate_api_key
from app.models.project import ProjectUserAssociation, ProjectUserRole
from tests.factories.project_factory import ProjectFactory
from tests.factories.user_factory import UserFactory


async def create_user_with_project_access(
    db_session: AsyncSession,
    *,
    user_name: str = "Test User",
    project_name: str = "Test Project",
    role: ProjectUserRole = ProjectUserRole.member,
) -> tuple[uuid.UUID, int]:
    """
    Create a user and project with proper association for testing.

    This helper standardizes the pattern of creating test users that have
    access to projects, which is needed for most project-scoped endpoint tests.

    Args:
        db_session: The async database session
        user_name: Name for the test user
        project_name: Name for the test project
        role: Role for the user in the project

    Returns:
        Tuple of (user_id, project_id) for fetching in tests

    Example:
        user_id, project_id = await create_user_with_project_access(db_session)
        # Now you can fetch the user/project or use IDs in API calls
    """
    # Create user and project
    user = await UserFactory.create_async(name=user_name)
    project = await ProjectFactory.create_async(name=project_name)

    # Create the project association
    association = ProjectUserAssociation(
        user_id=user.id,
        project_id=project.id,
        role=role,
    )
    db_session.add(association)
    await db_session.commit()

    return user.id, project.id


async def create_user_with_api_key_and_project_access(
    db_session: AsyncSession,
    *,
    user_name: str = "API Test User",
    project_name: str = "Test Project",
    role: ProjectUserRole = ProjectUserRole.member,
) -> tuple[uuid.UUID, int, str]:
    """
    Create a user with API key and project access for Control API testing.

    This helper creates the full setup needed for Control API tests:
    - User with API key
    - Project
    - User-project association

    Args:
        db_session: The async database session
        user_name: Name for the test user
        project_name: Name for the test project
        role: Role for the user in the project

    Returns:
        Tuple of (user_id, project_id, api_key) for testing

    Example:
        user_id, project_id, api_key = await create_user_with_api_key_and_project_access(db_session)
        headers = {"Authorization": f"Bearer {api_key}"}
        resp = await client.get(f"/api/v1/control/projects/{project_id}", headers=headers)
    """
    # Create user first, then generate API key with user ID
    user = await UserFactory.create_async(name=user_name)
    api_key = generate_api_key(user.id)
    user.api_key = api_key
    db_session.add(user)
    await db_session.commit()

    project = await ProjectFactory.create_async(name=project_name)

    # Create the project association
    association = ProjectUserAssociation(
        user_id=user.id,
        project_id=project.id,
        role=role,
    )
    db_session.add(association)
    await db_session.commit()

    return user.id, project.id, api_key
