"""Tests for database health checks."""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.health import check_database_health


@pytest.mark.asyncio
async def test_health_check_success(db_session: AsyncSession) -> None:
    """Test successful health check."""
    is_healthy, message = await check_database_health(db_session)
    assert is_healthy is True
    assert message == "Database is healthy"


@pytest.mark.asyncio
async def test_health_check_failure(db_session: AsyncSession) -> None:
    """Test health check failure."""
    # Close the session to simulate a connection error
    await db_session.close()

    is_healthy, message = await check_database_health(db_session)
    assert is_healthy is False
    assert "Database health check failed:" in message
