"""Test configuration and fixtures."""

import datetime
import logging
from collections.abc import AsyncGenerator, Generator
from typing import Any

import bcrypt
import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from minio import Minio
from pydantic import PostgresDsn
from sqlalchemy import insert
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from testcontainers.minio import MinioContainer  # type: ignore[import-untyped]
from testcontainers.postgres import PostgresContainer  # type: ignore[import-untyped]
from testcontainers.redis import RedisContainer  # type: ignore[import-untyped]

from app.core.auth import create_access_token
from app.core.deps import get_db
from app.db.config import DatabaseSettings
from app.main import app
from app.models.agent import Agent
from app.models.base import Base
from app.models.hash_type import HashType
from app.models.project import Project
from app.models.user import User, UserRole
from tests.factories.agent_error_factory import AgentErrorFactory
from tests.factories.agent_factory import AgentFactory
from tests.factories.attack_factory import AttackFactory
from tests.factories.attack_resource_file_factory import AttackResourceFileFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.task_factory import TaskFactory
from tests.factories.user_factory import UserFactory


# --- Test DB provisioning ---
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
        from tests.factories.project_factory import ProjectFactory
        from tests.factories.task_factory import TaskFactory
        from tests.factories.user_factory import UserFactory

        AgentFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        AgentErrorFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        AttackFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        CampaignFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        ProjectFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        TaskFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        UserFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        ProjectFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        HashListFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]
        AttackResourceFileFactory.__async_session__ = session  # type: ignore[assignment, unused-ignore]

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


# --- Polyfactory setup ---
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
def project_factory() -> ProjectFactory:
    return ProjectFactory()


@pytest.fixture
def campaign_factory() -> CampaignFactory:
    return CampaignFactory()


@pytest.fixture
def hash_list_factory() -> HashListFactory:
    return HashListFactory()


# --- Test data seeding ---
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


@pytest.fixture
def attack_resource_file_factory() -> AttackResourceFileFactory:
    return AttackResourceFileFactory()


class PropagateHandler(logging.Handler):
    def emit(self, record: logging.LogRecord) -> None:
        logging.getLogger(record.name).handle(record)


@pytest_asyncio.fixture
async def authenticated_async_client(
    async_client: AsyncClient, db_session: AsyncSession
) -> AsyncGenerator[AsyncClient]:
    """Yield an authenticated async_client with a valid user session for most tests."""
    user = await UserFactory.create_async()
    user.hashed_password = bcrypt.hashpw(b"password", bcrypt.gensalt()).decode()
    db_session.add(user)
    await db_session.commit()
    token = create_access_token(user.id)
    async_client.cookies.set("access_token", token)
    yield async_client


@pytest_asyncio.fixture
async def authenticated_user_client(
    async_client: AsyncClient, db_session: AsyncSession
) -> AsyncGenerator[tuple[AsyncClient, User]]:
    """Yield (async_client, user) for tests that need the user object for project membership, etc."""
    user = await UserFactory.create_async()
    user.hashed_password = bcrypt.hashpw(b"password", bcrypt.gensalt()).decode()
    db_session.add(user)
    await db_session.commit()
    token = create_access_token(user.id)
    async_client.cookies.set("access_token", token)
    yield async_client, user


@pytest_asyncio.fixture
async def authenticated_admin_client(
    async_client: AsyncClient, db_session: AsyncSession
) -> AsyncGenerator[AsyncClient]:
    """Yield an authenticated async_client with a valid admin user session for admin-only tests."""
    user = await UserFactory.create_async(role=UserRole.ADMIN, is_superuser=True)
    user.hashed_password = bcrypt.hashpw(b"password", bcrypt.gensalt()).decode()
    db_session.add(user)
    await db_session.commit()
    token = create_access_token(user.id)
    async_client.cookies.set("access_token", token)
    yield async_client


# --- Redis Testcontainer ---
@pytest.fixture(scope="session")
async def redis_container() -> AsyncGenerator[RedisContainer]:
    with RedisContainer("redis:7-alpine") as redis:
        yield redis


# --- MinIO Testcontainer ---
@pytest.fixture(scope="session")
def minio_client() -> Generator[Minio]:
    with MinioContainer(
        image="minio/minio:latest",
    ) as minio:
        minio_client: Minio = minio.get_client()
        # Patch settings to use the testcontainer endpoint and credentials
        config = minio.get_config()
        endpoint_url = config["endpoint"]
        access_key = config["access_key"]
        secret_key = config["secret_key"]
        from app.core import config as core_config

        core_config.settings.MINIO_ENDPOINT = endpoint_url
        core_config.settings.MINIO_ACCESS_KEY = access_key
        core_config.settings.MINIO_SECRET_KEY = secret_key

        # Ensure bucket exists (blocking)
        if not minio_client.bucket_exists(core_config.settings.MINIO_BUCKET):
            minio_client.make_bucket(core_config.settings.MINIO_BUCKET)

        yield minio_client
