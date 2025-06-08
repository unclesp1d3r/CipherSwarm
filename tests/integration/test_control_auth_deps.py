"""Integration tests for Control API authentication dependencies."""

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import (
    get_current_control_user,
    get_current_user_from_api_key,
    require_write_access,
)
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_get_current_user_from_api_key_with_full_key(
    db_session: AsyncSession, user_factory: UserFactory
) -> None:
    """Test authentication with full API key."""
    # Create user with API keys
    user = await user_factory.create_async()

    # Test with full API key
    result_user, is_readonly = await get_current_user_from_api_key(
        authorization=f"Bearer {user.api_key_full}", db=db_session
    )

    assert result_user.id == user.id
    assert result_user.email == user.email
    assert is_readonly is False


@pytest.mark.asyncio
async def test_get_current_user_from_api_key_with_readonly_key(
    db_session: AsyncSession, user_factory: UserFactory
) -> None:
    """Test authentication with readonly API key."""
    # Create user with API keys
    user = await user_factory.create_async()

    # Test with readonly API key
    result_user, is_readonly = await get_current_user_from_api_key(
        authorization=f"Bearer {user.api_key_readonly}", db=db_session
    )

    assert result_user.id == user.id
    assert result_user.email == user.email
    assert is_readonly is True


@pytest.mark.asyncio
async def test_get_current_user_from_api_key_missing_header(
    db_session: AsyncSession,
) -> None:
    """Test authentication fails with missing Authorization header."""
    with pytest.raises(HTTPException) as exc_info:
        await get_current_user_from_api_key(authorization="", db=db_session)

    assert exc_info.value.status_code == 401
    assert "Missing or invalid Authorization header" in exc_info.value.detail


@pytest.mark.asyncio
async def test_get_current_user_from_api_key_invalid_format(
    db_session: AsyncSession,
) -> None:
    """Test authentication fails with invalid header format."""
    with pytest.raises(HTTPException) as exc_info:
        await get_current_user_from_api_key(
            authorization="Invalid header", db=db_session
        )

    assert exc_info.value.status_code == 401
    assert "Missing or invalid Authorization header" in exc_info.value.detail


@pytest.mark.asyncio
async def test_get_current_user_from_api_key_invalid_key_format(
    db_session: AsyncSession,
) -> None:
    """Test authentication fails with invalid API key format."""
    with pytest.raises(HTTPException) as exc_info:
        await get_current_user_from_api_key(
            authorization="Bearer invalid_key_format", db=db_session
        )

    assert exc_info.value.status_code == 401
    assert "Invalid API key format" in exc_info.value.detail


@pytest.mark.asyncio
async def test_get_current_user_from_api_key_nonexistent_key(
    db_session: AsyncSession,
) -> None:
    """Test authentication fails with nonexistent API key."""
    fake_key = "cst_00000000-0000-0000-0000-000000000000_nonexistent"

    with pytest.raises(HTTPException) as exc_info:
        await get_current_user_from_api_key(
            authorization=f"Bearer {fake_key}", db=db_session
        )

    assert exc_info.value.status_code == 401
    assert "Invalid API key" in exc_info.value.detail


@pytest.mark.asyncio
async def test_get_current_user_from_api_key_inactive_user(
    db_session: AsyncSession, user_factory: UserFactory
) -> None:
    """Test authentication fails with inactive user."""
    # Create inactive user
    user = await user_factory.create_async(is_active=False)

    with pytest.raises(HTTPException) as exc_info:
        await get_current_user_from_api_key(
            authorization=f"Bearer {user.api_key_full}", db=db_session
        )

    assert exc_info.value.status_code == 403
    assert "Inactive user" in exc_info.value.detail


@pytest.mark.asyncio
async def test_require_write_access_with_full_key(
    db_session: AsyncSession, user_factory: UserFactory
) -> None:
    """Test write access is allowed with full API key."""
    user = await user_factory.create_async()

    # Mock the dependency return value
    user_and_readonly = (user, False)

    result_user = require_write_access(user_and_readonly)

    assert result_user.id == user.id


@pytest.mark.asyncio
async def test_require_write_access_with_readonly_key(
    db_session: AsyncSession, user_factory: UserFactory
) -> None:
    """Test write access is denied with readonly API key."""
    user = await user_factory.create_async()

    # Mock the dependency return value for readonly key
    user_and_readonly = (user, True)

    with pytest.raises(HTTPException) as exc_info:
        require_write_access(user_and_readonly)

    assert exc_info.value.status_code == 403
    assert "Read-only API key cannot perform write operations" in exc_info.value.detail


@pytest.mark.asyncio
async def test_get_current_control_user_with_full_key(
    db_session: AsyncSession, user_factory: UserFactory
) -> None:
    """Test get_current_control_user works with full API key."""
    user = await user_factory.create_async()

    # Mock the dependency return value
    user_and_readonly = (user, False)

    result_user = get_current_control_user(user_and_readonly)

    assert result_user.id == user.id


@pytest.mark.asyncio
async def test_get_current_control_user_with_readonly_key(
    db_session: AsyncSession, user_factory: UserFactory
) -> None:
    """Test get_current_control_user works with readonly API key."""
    user = await user_factory.create_async()

    # Mock the dependency return value for readonly key
    user_and_readonly = (user, True)

    result_user = get_current_control_user(user_and_readonly)

    assert result_user.id == user.id


@pytest.mark.asyncio
async def test_api_key_authentication_end_to_end(
    db_session: AsyncSession, user_factory: UserFactory
) -> None:
    """Test complete authentication flow from API key to user."""
    # Create user with API keys
    user = await user_factory.create_async()

    # Test full key authentication flow
    full_user, full_readonly = await get_current_user_from_api_key(
        authorization=f"Bearer {user.api_key_full}", db=db_session
    )

    # Should be able to get write access
    write_user = require_write_access((full_user, full_readonly))
    assert write_user.id == user.id

    # Should be able to get control user
    control_user = get_current_control_user((full_user, full_readonly))
    assert control_user.id == user.id

    # Test readonly key authentication flow
    readonly_user, readonly_flag = await get_current_user_from_api_key(
        authorization=f"Bearer {user.api_key_readonly}", db=db_session
    )

    # Should NOT be able to get write access
    with pytest.raises(HTTPException) as exc_info:
        require_write_access((readonly_user, readonly_flag))
    assert exc_info.value.status_code == 403

    # Should be able to get control user
    readonly_control_user = get_current_control_user((readonly_user, readonly_flag))
    assert readonly_control_user.id == user.id


@pytest.mark.asyncio
async def test_api_key_with_project_associations(
    db_session: AsyncSession, user_factory: UserFactory
) -> None:
    """Test that API key authentication loads project associations."""
    # Create user with API keys
    user = await user_factory.create_async()

    # Test that project associations are loaded
    result_user, _ = await get_current_user_from_api_key(
        authorization=f"Bearer {user.api_key_full}", db=db_session
    )

    # Verify project associations are loaded (even if empty)
    assert hasattr(result_user, "project_associations")
    assert result_user.project_associations is not None
