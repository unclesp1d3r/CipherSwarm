"""Database session management module."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from typing import Any

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from .config import DatabaseSettings


class DatabaseSessionManager:
    """Manages database sessions and engine lifecycle.

    This class is responsible for:
    - Creating and managing the database engine
    - Providing session factories
    - Managing connection pools
    - Handling cleanup
    """

    def __init__(self) -> None:
        """Initialize the session manager."""
        self._engine: AsyncEngine | None = None
        self._sessionmaker: async_sessionmaker[AsyncSession] | None = None
        self._settings: DatabaseSettings | None = None

    def init(self, settings: DatabaseSettings) -> None:
        """Initialize the database engine and session maker.

        Args:
            settings: Database configuration settings
        """
        self._settings = settings

        # Base engine arguments
        engine_args: dict[str, Any] = {"echo": settings.echo}

        # Only add pooling arguments for non-SQLite databases
        if not str(settings.url).startswith("sqlite"):
            engine_args.update(
                {
                    "pool_size": settings.pool_size,
                    "max_overflow": settings.max_overflow,
                    "pool_timeout": settings.pool_timeout,
                    "pool_recycle": settings.pool_recycle,
                }
            )

        self._engine = create_async_engine(str(settings.url), **engine_args)
        self._sessionmaker = async_sessionmaker(
            autocommit=False, autoflush=False, expire_on_commit=False, bind=self._engine
        )

    async def close(self) -> None:
        """Close all connections in the pool."""
        if self._engine:
            await self._engine.dispose()
            self._engine = None
            self._sessionmaker = None

    @asynccontextmanager
    async def session(self) -> AsyncGenerator[AsyncSession]:
        """Get a database session.

        Yields:
            AsyncSession: Database session

        Raises:
            RuntimeError: If session manager is not initialized
        """
        if not self._sessionmaker:
            raise RuntimeError("DatabaseSessionManager is not initialized")

        session = self._sessionmaker()
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

    @property
    def engine(self) -> AsyncEngine:
        """Get the database engine.

        Returns:
            AsyncEngine: The database engine

        Raises:
            RuntimeError: If session manager is not initialized
        """
        if not self._engine:
            raise RuntimeError("DatabaseSessionManager is not initialized")
        return self._engine


# Global instance of the session manager
sessionmanager = DatabaseSessionManager()


async def get_session() -> AsyncGenerator[AsyncSession]:
    """FastAPI dependency for database sessions.

    Yields:
        AsyncSession: Database session
    """
    async with sessionmanager.session() as session:
        yield session


# Alias for FastAPI DB dependency
get_db = get_session
