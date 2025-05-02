"""Test configuration and fixtures."""

from typing import AsyncGenerator

import pytest
import pytest_asyncio
from pytest_postgresql import factories
from pydantic import PostgresDsn
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    create_async_engine,
    async_sessionmaker,
)

from app.db.config import DatabaseSettings
from app.db.base import Base
from app.db.session import sessionmanager


# Create PostgreSQL process fixture - settings are now in pytest.ini
postgresql_proc = factories.postgresql_proc()
postgresql = factories.postgresql("postgresql_proc")


@pytest.fixture
def db_settings(postgresql) -> DatabaseSettings:
    """Create test database settings."""
    url = PostgresDsn.build(
        scheme="postgresql+asyncpg",
        username=postgresql.info.user,
        password=postgresql.info.password or "",
        host=postgresql.info.host,
        port=postgresql.info.port,
        path=postgresql.info.dbname,
    )
    return DatabaseSettings(
        url=url,
        pool_size=5,
        max_overflow=10,
        pool_timeout=30,
        pool_recycle=1800,
        echo=False,
    )


@pytest.fixture(autouse=True)
def initialize_session_manager(db_settings: DatabaseSettings) -> None:
    """Initialize the session manager for tests."""
    sessionmanager.init(db_settings)


@pytest_asyncio.fixture
async def db_engine(db_settings: DatabaseSettings) -> AsyncGenerator[AsyncEngine, None]:
    """Create test database engine."""
    engine = create_async_engine(
        str(db_settings.url),
        pool_size=db_settings.pool_size,
        max_overflow=db_settings.max_overflow,
        pool_timeout=db_settings.pool_timeout,
        pool_recycle=db_settings.pool_recycle,
        echo=db_settings.echo,
    )

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    try:
        yield engine
    finally:
        await engine.dispose()


@pytest.fixture
def db_session_maker(db_engine: AsyncEngine) -> async_sessionmaker[AsyncSession]:
    """Create test database session maker."""
    return async_sessionmaker(
        bind=db_engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False,
    )


@pytest_asyncio.fixture
async def db_session(
    db_session_maker: async_sessionmaker[AsyncSession],
) -> AsyncGenerator[AsyncSession, None]:
    """Create test database session."""
    async with db_session_maker() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


@pytest_asyncio.fixture(autouse=True)
async def clean_tables(db_engine: AsyncEngine) -> AsyncGenerator[None, None]:
    """Clean all tables after each test."""
    try:
        yield
    finally:
        async with db_engine.begin() as conn:
            for table in reversed(Base.metadata.sorted_tables):
                await conn.execute(table.delete())
