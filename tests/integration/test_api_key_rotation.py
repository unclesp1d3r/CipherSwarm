"""Integration tests for API key rotation functionality."""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user_from_api_key
from app.core.services.user_service import rotate_user_api_keys_service
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_api_key_rotation_invalidates_old_keys(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    """Test that rotating API keys invalidates the old keys."""
    # Create a user with API keys
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    original_full_key = user.api_key_full
    original_readonly_key = user.api_key_readonly

    # Verify original keys work
    user_from_full, is_readonly_full = await get_current_user_from_api_key(
        authorization=f"Bearer {original_full_key}", db=db_session
    )
    assert user_from_full.id == user.id
    assert is_readonly_full is False

    user_from_readonly, is_readonly_readonly = await get_current_user_from_api_key(
        authorization=f"Bearer {original_readonly_key}", db=db_session
    )
    assert user_from_readonly.id == user.id
    assert is_readonly_readonly is True

    # Rotate the API keys
    new_full_key, new_readonly_key = await rotate_user_api_keys_service(
        db_session, user.id
    )

    # Verify new keys work
    user_from_new_full, is_readonly_new_full = await get_current_user_from_api_key(
        authorization=f"Bearer {new_full_key}", db=db_session
    )
    assert user_from_new_full.id == user.id
    assert is_readonly_new_full is False

    (
        user_from_new_readonly,
        is_readonly_new_readonly,
    ) = await get_current_user_from_api_key(
        authorization=f"Bearer {new_readonly_key}", db=db_session
    )
    assert user_from_new_readonly.id == user.id
    assert is_readonly_new_readonly is True

    # Verify old keys no longer work
    from fastapi import HTTPException

    with pytest.raises(HTTPException) as exc_info:
        await get_current_user_from_api_key(
            authorization=f"Bearer {original_full_key}", db=db_session
        )
    assert exc_info.value.status_code == 401
    assert "Invalid API key" in exc_info.value.detail

    with pytest.raises(HTTPException) as exc_info:
        await get_current_user_from_api_key(
            authorization=f"Bearer {original_readonly_key}", db=db_session
        )
    assert exc_info.value.status_code == 401
    assert "Invalid API key" in exc_info.value.detail


@pytest.mark.asyncio
async def test_api_key_rotation_preserves_user_data(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    """Test that rotating API keys preserves all other user data."""
    # Create a user with API keys
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    original_email = user.email
    original_name = user.name
    original_role = user.role
    original_is_active = user.is_active
    original_is_superuser = user.is_superuser

    # Rotate the API keys
    await rotate_user_api_keys_service(db_session, user.id)

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
    # Create a user with API keys
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)

    # Simulate concurrent rotations (in practice this would be rare but possible)
    # Both should succeed and the final state should be consistent
    new_full_key_1, new_readonly_key_1 = await rotate_user_api_keys_service(
        db_session, user.id
    )
    new_full_key_2, new_readonly_key_2 = await rotate_user_api_keys_service(
        db_session, user.id
    )

    # Verify the final keys are the latest ones
    await db_session.refresh(user)
    assert user.api_key_full == new_full_key_2
    assert user.api_key_readonly == new_readonly_key_2

    # Verify the first set of keys no longer work
    from fastapi import HTTPException

    with pytest.raises(HTTPException):
        await get_current_user_from_api_key(
            authorization=f"Bearer {new_full_key_1}", db=db_session
        )

    with pytest.raises(HTTPException):
        await get_current_user_from_api_key(
            authorization=f"Bearer {new_readonly_key_1}", db=db_session
        )

    # Verify the latest keys work
    user_from_latest_full, _ = await get_current_user_from_api_key(
        authorization=f"Bearer {new_full_key_2}", db=db_session
    )
    assert user_from_latest_full.id == user.id

    user_from_latest_readonly, _ = await get_current_user_from_api_key(
        authorization=f"Bearer {new_readonly_key_2}", db=db_session
    )
    assert user_from_latest_readonly.id == user.id
