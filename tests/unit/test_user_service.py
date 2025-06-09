"""Tests for user service functions."""

import pytest
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.user_service import rotate_user_api_key_service
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_rotate_user_api_key_service(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    """Test that rotate_user_api_key_service generates a new API key."""
    # Create a user with existing API key
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    original_key = user.api_key
    original_created_at = user.api_key_created_at

    # Rotate the API key
    new_key = await rotate_user_api_key_service(db_session, user.id)

    # Refresh the user from the database
    await db_session.refresh(user)

    # Verify new key is different from original key
    assert new_key != original_key
    assert user.api_key == new_key

    # Verify new key follows the correct format
    assert new_key.startswith("cst_")
    assert str(user.id) in new_key

    # Verify timestamp is updated
    assert user.api_key_created_at != original_created_at
    assert user.api_key_created_at is not None


@pytest.mark.asyncio
async def test_rotate_user_api_key_service_nonexistent_user(
    db_session: AsyncSession,
) -> None:
    """Test that rotate_user_api_key_service raises NoResultFound for nonexistent user."""
    from uuid import uuid4

    nonexistent_user_id = uuid4()

    with pytest.raises(
        NoResultFound, match=f"User with id {nonexistent_user_id} not found"
    ):
        await rotate_user_api_key_service(db_session, nonexistent_user_id)


@pytest.mark.asyncio
async def test_rotate_user_api_key_service_multiple_rotations(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    """Test that multiple rotations generate different keys each time."""
    # Create a user
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    # Perform first rotation
    first_key = await rotate_user_api_key_service(db_session, user.id)

    # Perform second rotation
    second_key = await rotate_user_api_key_service(db_session, user.id)

    # Verify keys are different
    assert first_key != second_key

    # Verify the user has the latest key
    await db_session.refresh(user)
    assert user.api_key == second_key
