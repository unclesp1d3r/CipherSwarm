import io
from uuid import uuid4

import pytest
from httpx import AsyncClient
from minio import Minio
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.ext.mutable import MutableDict

from app.core.config import settings
from app.models.agent import Agent
from app.models.attack_resource_file import AttackResourceFile, AttackResourceType
from tests.factories.agent_factory import AgentFactory
from tests.factories.attack_resource_file_factory import AttackResourceFileFactory


@pytest.mark.asyncio
async def test_v1_download_file_backed_resource(
    async_client: AsyncClient,
    minio_client: Minio,
    agent_factory: AgentFactory,
    attack_resource_file_factory: AttackResourceFileFactory,
    db_session: AsyncSession,
    authenticated_async_client: AsyncClient,
) -> None:
    # Create agent and resource
    agent: Agent = await agent_factory.create_async()
    resource: AttackResourceFile = await attack_resource_file_factory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        is_uploaded=True,
        file_name="file.txt",
        line_count=2,
        byte_size=20,
    )
    # Upload file to MinIO
    minio_client.put_object(
        settings.MINIO_BUCKET, str(resource.id), io.BytesIO(b"alpha\nbeta\n"), length=11
    )
    # Call download endpoint
    url = f"/api/v1/downloads/{resource.id}/download"
    headers = {"Authorization": f"Bearer {agent.token}"}
    resp = await async_client.get(url, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["url"].startswith("http")
    # Should be a presigned URL
    assert f"/{settings.MINIO_BUCKET}/" in data["url"]


@pytest.mark.asyncio
async def test_v1_download_ephemeral_resource(
    async_client: AsyncClient, agent_factory: AgentFactory, db_session: AsyncSession
) -> None:
    agent = await agent_factory.create_async()
    resource = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.EPHEMERAL_WORD_LIST,
        is_uploaded=False,
        file_name="ephemeral.txt",
        content=MutableDict({"lines": ["foo", "bar"]}),
        line_count=2,
        byte_size=7,
    )
    url = f"/api/v1/downloads/{resource.id}/download"
    headers = {"Authorization": f"Bearer {agent.token}"}
    resp = await async_client.get(url, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    # Should be an internal ephemeral-download URL
    assert data["url"].endswith(f"/api/v1/downloads/{resource.id}/ephemeral-download")
    # Now actually download the ephemeral file
    file_url = data["url"]
    file_resp = await async_client.get(file_url, headers=headers)
    assert file_resp.status_code == 200
    assert file_resp.headers["content-type"].startswith("text/plain")
    assert file_resp.text == "foo\nbar"


@pytest.mark.asyncio
async def test_v1_download_invalid_token(async_client: AsyncClient) -> None:
    resource: AttackResourceFile = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.EPHEMERAL_WORD_LIST,
        is_uploaded=False,
        file_name="ephemeral.txt",
        content=MutableDict({"lines": ["foo", "bar"]}),
        line_count=2,
        byte_size=7,
    )
    url = f"/api/v1/downloads/{resource.id}/download"
    headers = {"Authorization": "Bearer invalidtoken"}
    resp = await async_client.get(url, headers=headers)
    assert resp.status_code == 401
    # Also test ephemeral-download endpoint
    file_url = f"/api/v1/downloads/{resource.id}/ephemeral-download"
    file_resp = await async_client.get(file_url, headers=headers)
    assert file_resp.status_code == 401


@pytest.mark.asyncio
async def test_v1_download_missing_resource(
    async_client: AsyncClient, agent_factory: AgentFactory, db_session: AsyncSession
) -> None:
    agent = await agent_factory.create_async()
    fake_id = uuid4()
    url = f"/api/v1/downloads/{fake_id}/download"
    headers = {"Authorization": f"Bearer {agent.token}"}
    resp = await async_client.get(url, headers=headers)
    assert resp.status_code == 404
    file_url = f"/api/v1/downloads/{fake_id}/ephemeral-download"
    file_resp = await async_client.get(file_url, headers=headers)
    assert file_resp.status_code == 404


@pytest.mark.asyncio
async def test_v1_ephemeral_download_wrong_type(
    async_client: AsyncClient, agent_factory: AgentFactory, db_session: AsyncSession
) -> None:
    agent: Agent = await agent_factory.create_async()
    resource: AttackResourceFile = await AttackResourceFileFactory.create_async(
        resource_type=AttackResourceType.WORD_LIST,
        is_uploaded=True,
        file_name="file.txt",
        line_count=2,
        byte_size=20,
    )
    file_url = f"/api/v1/downloads/{resource.id}/ephemeral-download"
    headers = {"Authorization": f"Bearer {agent.token}"}
    file_resp = await async_client.get(file_url, headers=headers)
    assert file_resp.status_code == 404
