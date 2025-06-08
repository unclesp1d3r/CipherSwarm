"""Integration tests for user service functionality."""

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.user_service import create_user_service
from app.models.user import User, UserRole
from app.schemas.user import UserCreate


@pytest.mark.asyncio
async def test_create_user_generates_api_keys(db_session: AsyncSession) -> None:
    """Test that creating a user automatically generates API keys."""
    user_data = UserCreate(
        email="test@example.com", name="Test User", password="testpassword123"
    )

    # Create user using the service
    user_read = await create_user_service(
        db=db_session, user_in=user_data, role=UserRole.ANALYST
    )

    # Verify user was created
    assert user_read.email == "test@example.com"
    assert user_read.name == "Test User"
    assert user_read.role == "analyst"

    # Fetch the actual user from database to check API keys
    result = await db_session.execute(select(User).where(User.id == user_read.id))
    user = result.scalar_one()

    # Verify API keys were generated
    assert user.api_key_full is not None
    assert user.api_key_readonly is not None
    assert user.api_key_full_created_at is not None
    assert user.api_key_readonly_created_at is not None

    # Verify API key format: cst_<user_id>_<random>
    assert user.api_key_full.startswith("cst_")
    assert user.api_key_readonly.startswith("cst_")

    full_parts = user.api_key_full.split("_")
    readonly_parts = user.api_key_readonly.split("_")

    assert len(full_parts) == 3
    assert len(readonly_parts) == 3
    assert full_parts[1] == str(user.id)
    assert readonly_parts[1] == str(user.id)

    # Keys should be different
    assert user.api_key_full != user.api_key_readonly


@pytest.mark.asyncio
async def test_create_user_api_keys_are_unique(db_session: AsyncSession) -> None:
    """Test that each user gets unique API keys."""
    user1_data = UserCreate(
        email="user1@example.com", name="User One", password="password123"
    )

    user2_data = UserCreate(
        email="user2@example.com", name="User Two", password="password123"
    )

    # Create two users
    user1_read = await create_user_service(db=db_session, user_in=user1_data)
    user2_read = await create_user_service(db=db_session, user_in=user2_data)

    # Fetch users from database
    result1 = await db_session.execute(select(User).where(User.id == user1_read.id))
    user1 = result1.scalar_one()

    result2 = await db_session.execute(select(User).where(User.id == user2_read.id))
    user2 = result2.scalar_one()

    # Verify all API keys are unique
    assert user1.api_key_full != user2.api_key_full
    assert user1.api_key_readonly != user2.api_key_readonly
    assert user1.api_key_full != user1.api_key_readonly
    assert user2.api_key_full != user2.api_key_readonly


@pytest.mark.asyncio
async def test_create_user_api_key_timestamps(db_session: AsyncSession) -> None:
    """Test that API key creation timestamps are set correctly."""
    user_data = UserCreate(
        email="timestamp@example.com", name="Timestamp User", password="password123"
    )

    # Create user
    user_read = await create_user_service(db=db_session, user_in=user_data)

    # Fetch user from database
    result = await db_session.execute(select(User).where(User.id == user_read.id))
    user = result.scalar_one()

    # Verify timestamps are set and are recent
    assert user.api_key_full_created_at is not None
    assert user.api_key_readonly_created_at is not None

    # Both timestamps should be the same (created at the same time)
    assert user.api_key_full_created_at == user.api_key_readonly_created_at
