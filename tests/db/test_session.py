"""Tests for database session management."""

import contextlib

import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.config import DatabaseSettings
from app.db.session import DatabaseSessionManager


@pytest.mark.asyncio
async def test_session_manager_initialization(db_settings: DatabaseSettings) -> None:
    """Test session manager initialization."""
    manager = DatabaseSessionManager()
    manager.init(db_settings)

    assert manager.engine is not None


@pytest.mark.asyncio
async def test_session_manager_close(db_settings: DatabaseSettings) -> None:
    """Test session manager cleanup."""
    manager = DatabaseSessionManager()
    manager.init(db_settings)

    await manager.close()
    assert manager._engine is None
    assert manager._sessionmaker is None


@pytest.mark.asyncio
async def test_session_context_manager(db_settings: DatabaseSettings) -> None:
    """Test session context manager functionality."""
    manager = DatabaseSessionManager()
    manager.init(db_settings)

    async with manager.session() as session:
        assert isinstance(session, AsyncSession)
        # Test that session is active
        result = await session.execute(text("SELECT 1"))
        value = result.scalar_one()
        assert value == 1


async def _raise_and_rollback(manager: DatabaseSessionManager) -> None:
    async with manager.session() as session:
        result = await session.execute(text("SELECT 1"))
        value = result.scalar_one()
        assert value == 1
        raise ValueError("Test error")


@pytest.mark.asyncio
async def test_session_rollback_on_error(db_settings: DatabaseSettings) -> None:
    """Test session rollback on error."""
    manager = DatabaseSessionManager()
    manager.init(db_settings)

    with pytest.raises(ValueError):
        await _raise_and_rollback(manager)


@pytest.mark.asyncio
async def test_get_session_dependency(db_settings: DatabaseSettings) -> None:
    """Test the FastAPI session dependency."""
    from app.db import session as db_session_module

    db_session_module.sessionmanager.init(db_settings)
    session_gen = db_session_module.get_session()
    session = await anext(session_gen)

    assert isinstance(session, AsyncSession)
    # Test that session is usable
    result = await session.execute(text("SELECT 1"))
    value = result.scalar_one()
    assert value == 1

    # Clean up
    with contextlib.suppress(Exception):
        await session.close()
