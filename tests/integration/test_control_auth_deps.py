"""
Integration tests for Control API authentication dependencies.

Tests the authentication flow for API keys in the Control API.
"""

from http import HTTPStatus

import pytest
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_control_user
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_get_current_control_user_with_api_key(
    db_session: AsyncSession, user_factory: UserFactory
) -> None:
    """Test get_current_control_user works with API key."""
    user = await user_factory.create_async()

    # Test the simplified function directly
    result_user = await get_current_control_user(
        authorization=f"Bearer {user.api_key}", db=db_session
    )

    assert result_user.id == user.id


@pytest.mark.asyncio
async def test_get_current_control_user_with_invalid_key(
    db_session: AsyncSession, user_factory: UserFactory
) -> None:
    """Test get_current_control_user rejects invalid API key."""
    # Test with invalid key format
    with pytest.raises(HTTPException) as exc_info:
        await get_current_control_user(
            authorization="Bearer invalid_key", db=db_session
        )
    assert exc_info.value.status_code == HTTPStatus.UNAUTHORIZED

    # Test with valid format but non-existent key
    with pytest.raises(HTTPException) as exc_info:
        await get_current_control_user(
            authorization="Bearer cst_00000000-0000-0000-0000-000000000000_invalid",
            db=db_session,
        )
    assert exc_info.value.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_api_key_authentication_end_to_end(
    db_session: AsyncSession, user_factory: UserFactory
) -> None:
    """Test complete authentication flow from API key to user."""
    # Create user with API key
    user = await user_factory.create_async()

    # Test API key authentication flow
    authenticated_user = await get_current_control_user(
        authorization=f"Bearer {user.api_key}", db=db_session
    )

    assert authenticated_user.id == user.id
    assert authenticated_user.api_key == user.api_key
