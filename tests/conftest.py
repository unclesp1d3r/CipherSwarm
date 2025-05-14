"""Test configuration and fixtures."""

import datetime
import logging
from collections.abc import AsyncGenerator, Generator
from typing import Any

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from pydantic import PostgresDsn
from sqlalchemy import insert
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from testcontainers.postgres import PostgresContainer  # type: ignore[import-untyped]

from app.core.deps import get_db
from app.db.config import DatabaseSettings
from app.main import app
from app.models.agent import Agent
from app.models.base import Base
from app.models.hash_type import HashType
from app.models.project import Project
from tests.factories.agent_error_factory import AgentErrorFactory
from tests.factories.agent_factory import AgentFactory
from tests.factories.attack_factory import AttackFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.operating_system_factory import OperatingSystemFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.task_factory import TaskFactory
from tests.factories.user_factory import UserFactory


# Test DB provisioning
@pytest.fixture(scope="session")
def pg_container_url() -> Generator[str]:
    """Start a Postgres test container and yield a psycopg connection string."""
    with PostgresContainer("postgres:16", driver="psycopg") as postgres:
        url = postgres.get_connection_url()
        yield url


@pytest.fixture
def sync_db_url(pg_container_url: str) -> str:
    return pg_container_url


@pytest.fixture
def db_url(pg_container_url: str) -> str:
    return pg_container_url


@pytest_asyncio.fixture(scope="function")
async def async_engine(db_url: str) -> AsyncGenerator[AsyncEngine]:
    engine = create_async_engine(db_url, future=True)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest_asyncio.fixture(scope="function")
async def db_session(async_engine: Any) -> AsyncGenerator[AsyncSession, Any]:
    async_session = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with async_session() as session:
        # Set Polyfactory async session for all factories
        from tests.factories.agent_error_factory import AgentErrorFactory
        from tests.factories.agent_factory import AgentFactory
        from tests.factories.attack_factory import AttackFactory
        from tests.factories.campaign_factory import CampaignFactory
        from tests.factories.hash_list_factory import HashListFactory
        from tests.factories.operating_system_factory import OperatingSystemFactory
        from tests.factories.project_factory import ProjectFactory
        from tests.factories.task_factory import TaskFactory
        from tests.factories.user_factory import UserFactory

        AgentFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        AgentErrorFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        AttackFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        CampaignFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        OperatingSystemFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        ProjectFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        TaskFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        UserFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        ProjectFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        HashListFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]

        yield session


@pytest_asyncio.fixture(autouse=True)
async def reset_db_and_seed_hash_types(db_session: AsyncSession) -> None:
    # Truncate all tables
    for table in reversed(Base.metadata.sorted_tables):
        await db_session.execute(table.delete())
    # Reseed minimal hash_types
    now = datetime.datetime.now(datetime.UTC)
    await db_session.execute(
        insert(HashType),
        [
            {
                "id": 0,
                "name": "MD5",
                "description": "Raw Hash",
                "created_at": now,
                "updated_at": now,
            },
            {
                "id": 1,
                "name": "SHA1",
                "description": "Raw Hash",
                "created_at": now,
                "updated_at": now,
            },
            {
                "id": 100,
                "name": "SHA1-100",
                "description": "Raw Hash",
                "created_at": now,
                "updated_at": now,
            },
        ],
    )
    await db_session.commit()


# Polyfactory setup
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
def campaign_factory() -> CampaignFactory:
    return CampaignFactory()


@pytest.fixture
def hash_list_factory() -> HashListFactory:
    return HashListFactory()


@pytest.fixture
def db_settings(db_url: str) -> DatabaseSettings:
    """Fixture for DatabaseSettings using the test database URL."""
    return DatabaseSettings(url=PostgresDsn(db_url))


@pytest_asyncio.fixture
async def async_client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient]:
    async def override_get_db() -> AsyncGenerator[AsyncSession]:
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def seed_minimal_project(
    db_session: AsyncSession, project_factory: ProjectFactory
) -> Project:
    project: Project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    return project


@pytest_asyncio.fixture
async def seed_minimal_agent(
    db_session: AsyncSession, agent_factory: AgentFactory
) -> Agent:
    agent: Agent = agent_factory.build()
    db_session.add(agent)
    await db_session.commit()
    return agent


class PropagateHandler(logging.Handler):
    def emit(self, record: logging.LogRecord) -> None:
        logging.getLogger(record.name).handle(record)
