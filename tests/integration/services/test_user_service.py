"""Integration tests for user service functionality."""

from datetime import UTC, datetime

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.user_service import create_user_service
from app.models.user import User, UserRole
from app.schemas.user import UserCreate


@pytest.mark.asyncio
async def test_create_user_generates_api_keys(db_session: AsyncSession) -> None:
    """Test that creating a user automatically generates API key."""
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

    # Fetch the actual user from database to check API key
    result = await db_session.execute(select(User).where(User.id == user_read.id))
    user = result.scalar_one()

    # Verify API key was generated
    assert user.api_key is not None
    assert user.api_key_created_at is not None

    # Verify API key format: cst_<uuid>_<random>
    assert user.api_key.startswith("cst_")
    parts = user.api_key.split("_")
    assert len(parts) == 3
    assert parts[0] == "cst"
    # parts[1] should be a valid UUID (the user ID)
    import uuid

    uuid.UUID(parts[1])
    # parts[2] should be a hex string
    assert len(parts[2]) == 48


@pytest.mark.asyncio
async def test_create_user_api_keys_are_unique(db_session: AsyncSession) -> None:
    """Test that each user gets unique API key."""
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

    # Verify API keys are unique
    assert user1.api_key != user2.api_key
    assert user1.api_key is not None
    assert user2.api_key is not None


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
    assert user.api_key_created_at is not None
    # Should be within the last minute
    time_diff = datetime.now(UTC) - user.api_key_created_at
    assert time_diff.total_seconds() < 60
