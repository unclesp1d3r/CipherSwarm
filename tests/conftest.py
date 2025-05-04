"""Test configuration and fixtures."""

from collections.abc import AsyncGenerator, Generator
from typing import Any

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from pydantic import PostgresDsn
from pytest_postgresql import factories
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import async_sessionmaker
from sqlalchemy.ext.asyncio.engine import AsyncEngine
from sqlalchemy.ext.asyncio.session import AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy.orm.session import Session

from app.core.deps import get_db
from app.db.base import Base
from app.db.config import DatabaseSettings
from app.main import app
from tests.factories.agent_error_factory import AgentErrorFactory
from tests.factories.agent_factory import AgentFactory
from tests.factories.attack_factory import AttackFactory
from tests.factories.operating_system_factory import OperatingSystemFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.task_factory import TaskFactory
from tests.factories.user_factory import UserFactory

postgresql_proc = factories.postgresql_proc()
postgresql = factories.postgresql("postgresql_proc")


@pytest.fixture
def sync_db_url(postgresql: Any) -> str:
    return (
        f"postgresql://{postgresql.info.user}:{postgresql.info.password}"
        f"@{postgresql.info.host}:{postgresql.info.port}/{postgresql.info.dbname}"
    )


@pytest.fixture
def sqlalchemy_session(sync_db_url: str) -> Generator[Session, Any]:
    engine = create_engine(sync_db_url)
    Base.metadata.create_all(engine)
    session_factory = sessionmaker(bind=engine)
    session = session_factory()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture
def db_url(postgresql: Any) -> str:
    return (
        f"postgresql+asyncpg://{postgresql.info.user}:{postgresql.info.password}"
        f"@{postgresql.info.host}:{postgresql.info.port}/{postgresql.info.dbname}"
    )


@pytest_asyncio.fixture
async def async_engine(db_url: str) -> AsyncGenerator[AsyncEngine, Any]:
    from sqlalchemy.ext.asyncio import create_async_engine

    from app.db.base import Base

    engine = create_async_engine(db_url, future=True)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest_asyncio.fixture
async def db_session(async_engine: Any) -> AsyncGenerator[AsyncSession, Any]:
    from sqlalchemy.ext.asyncio import AsyncSession

    async_session = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with async_session() as session:
        yield session


@pytest_asyncio.fixture(autouse=True)
async def clean_tables(async_engine: Any) -> AsyncGenerator[None, Any]:
    yield
    async with async_engine.begin() as conn:
        for table in reversed(Base.metadata.sorted_tables):
            await conn.execute(table.delete())


@pytest.fixture(autouse=True)
def sync_create_all_tables(db_url: str) -> Generator[None, Any] | None:
    from sqlalchemy import create_engine

    from app.db.base import Base

    # Convert asyncpg URL to sync psycopg2 URL
    sync_url = db_url.replace("+asyncpg", "")
    engine = create_engine(sync_url)
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    engine.dispose()


# Polyfactory fixtures for all model factories
@pytest.fixture
def user_factory() -> UserFactory:
    return UserFactory()


@pytest.fixture
def agent_factory() -> AgentFactory:
    return AgentFactory()


@pytest.fixture
def agent_error_factory() -> AgentErrorFactory:
    return AgentErrorFactory()


@pytest.fixture
def attack_factory() -> AttackFactory:
    return AttackFactory()


@pytest.fixture
def task_factory() -> TaskFactory:
    return TaskFactory()


@pytest.fixture
def operating_system_factory() -> OperatingSystemFactory:
    return OperatingSystemFactory()


@pytest.fixture
def project_factory() -> ProjectFactory:
    return ProjectFactory()


@pytest.fixture
def db_settings(db_url: str) -> DatabaseSettings:
    """Fixture for DatabaseSettings using the test database URL."""
    return DatabaseSettings(url=PostgresDsn(db_url))


@pytest_asyncio.fixture
async def async_client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient]:
    # Override the app's get_db dependency to use the test db_session
    async def override_get_db() -> AsyncGenerator[AsyncSession]:
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client
    app.dependency_overrides.clear()
