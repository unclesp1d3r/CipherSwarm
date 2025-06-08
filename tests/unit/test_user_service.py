"""Tests for user service functions."""

import pytest
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.user_service import rotate_user_api_keys_service
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_rotate_user_api_keys_service(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    """Test that rotate_user_api_keys_service generates new API keys."""
    # Create a user with existing API keys
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    original_full_key = user.api_key_full
    original_readonly_key = user.api_key_readonly
    original_full_created_at = user.api_key_full_created_at
    original_readonly_created_at = user.api_key_readonly_created_at

    # Rotate the API keys
    new_full_key, new_readonly_key = await rotate_user_api_keys_service(
        db_session, user.id
    )

    # Refresh the user from the database
    await db_session.refresh(user)

    # Verify new keys are different from original keys
    assert new_full_key != original_full_key
    assert new_readonly_key != original_readonly_key
    assert user.api_key_full == new_full_key
    assert user.api_key_readonly == new_readonly_key

    # Verify new keys follow the correct format
    assert new_full_key.startswith("cst_")
    assert new_readonly_key.startswith("cst_")
    assert str(user.id) in new_full_key
    assert str(user.id) in new_readonly_key

    # Verify timestamps are updated
    assert user.api_key_full_created_at != original_full_created_at
    assert user.api_key_readonly_created_at != original_readonly_created_at
    assert user.api_key_full_created_at is not None
    assert user.api_key_readonly_created_at is not None

    # Verify the keys are unique
    assert new_full_key != new_readonly_key


@pytest.mark.asyncio
async def test_rotate_user_api_keys_service_nonexistent_user(
    db_session: AsyncSession,
) -> None:
    """Test that rotate_user_api_keys_service raises NoResultFound for nonexistent user."""
    from uuid import uuid4

    nonexistent_user_id = uuid4()

    with pytest.raises(
        NoResultFound, match=f"User with id {nonexistent_user_id} not found"
    ):
        await rotate_user_api_keys_service(db_session, nonexistent_user_id)


@pytest.mark.asyncio
async def test_rotate_user_api_keys_service_multiple_rotations(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    """Test that multiple rotations generate different keys each time."""
    # Create a user
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    # Perform first rotation
    first_full_key, first_readonly_key = await rotate_user_api_keys_service(
        db_session, user.id
    )

    # Perform second rotation
    second_full_key, second_readonly_key = await rotate_user_api_keys_service(
        db_session, user.id
    )

    # Verify all keys are different
    assert first_full_key != second_full_key
    assert first_readonly_key != second_readonly_key
    assert first_full_key != first_readonly_key
    assert second_full_key != second_readonly_key

    # Verify the user has the latest keys
    await db_session.refresh(user)
    assert user.api_key_full == second_full_key
    assert user.api_key_readonly == second_readonly_key
