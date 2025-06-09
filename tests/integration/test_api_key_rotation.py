"""Integration tests for API key rotation functionality."""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_control_user
from app.core.services.user_service import rotate_user_api_key_service
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_api_key_rotation_invalidates_old_key(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    """Test that rotating API key invalidates the old key."""
    # Create a user with API key
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    original_key = user.api_key

    # Verify original key works
    user_from_key = await get_current_control_user(
        authorization=f"Bearer {original_key}", db=db_session
    )
    assert user_from_key.id == user.id

    # Rotate the API key
    new_key = await rotate_user_api_key_service(db_session, user.id)

    # Verify new key works
    user_from_new_key = await get_current_control_user(
        authorization=f"Bearer {new_key}", db=db_session
    )
    assert user_from_new_key.id == user.id

    # Verify old key no longer works
    from fastapi import HTTPException

    with pytest.raises(HTTPException) as exc_info:
        await get_current_control_user(
            authorization=f"Bearer {original_key}", db=db_session
        )
    assert exc_info.value.status_code == 401
    assert "Invalid API key" in exc_info.value.detail


@pytest.mark.asyncio
async def test_api_key_rotation_preserves_user_data(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    """Test that rotating API key preserves all other user data."""
    # Create a user with API key
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    original_email = user.email
    original_name = user.name
    original_role = user.role
    original_is_active = user.is_active
    original_is_superuser = user.is_superuser

    # Rotate the API key
    await rotate_user_api_key_service(db_session, user.id)

    # Refresh the user from the database
    await db_session.refresh(user)

    # Verify all other user data is preserved
    assert user.email == original_email
    assert user.name == original_name
    assert user.role == original_role
    assert user.is_active == original_is_active
    assert user.is_superuser == original_is_superuser


@pytest.mark.asyncio
async def test_api_key_rotation_concurrent_safety(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    """Test that API key rotation is safe under concurrent access."""
    # Create a user with API key
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    # Simulate concurrent rotations (in practice this would be rare but possible)
    # Both should succeed and the final state should be consistent
    new_key_1 = await rotate_user_api_key_service(db_session, user.id)
    new_key_2 = await rotate_user_api_key_service(db_session, user.id)

    # Verify the final key is the latest one
    await db_session.refresh(user)
    assert user.api_key == new_key_2

    # Verify the first key no longer works
    from fastapi import HTTPException

    with pytest.raises(HTTPException):
        await get_current_control_user(
            authorization=f"Bearer {new_key_1}", db=db_session
        )

    # Verify the latest key works
    user_from_latest_key = await get_current_control_user(
        authorization=f"Bearer {new_key_2}", db=db_session
    )
    assert user_from_latest_key.id == user.id
