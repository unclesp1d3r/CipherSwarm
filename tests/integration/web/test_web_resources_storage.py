import io
import uuid

import httpx
import pytest
from httpx import AsyncClient
from minio import Minio
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from tests.factories.attack_resource_file_factory import AttackResourceFileFactory


@pytest.mark.asyncio
async def test_orphan_audit_detects_s3_and_db_orphans(
    authenticated_admin_client: AsyncClient,
    db_session: AsyncSession,
    minio_client: Minio,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    # Setup MinIO client
    bucket = settings.MINIO_BUCKET

    # Ensure bucket exists
    if not minio_client.bucket_exists(bucket):
        minio_client.make_bucket(bucket)

    # 1. Create a DB resource with no S3 object (DB orphan)
    db_orphan = await attack_resource_file_factory.create_async()
    # 2. Upload an S3 object with no DB record (S3 orphan)
    s3_orphan_key = f"orphan-{uuid.uuid4()}"
    minio_client.put_object(
        bucket,
        s3_orphan_key,
        io.BytesIO(b"orphaned content"),
        length=len(b"orphaned content"),
    )
    # 3. Create a resource with a matching S3 object (not orphaned)
    linked = await attack_resource_file_factory.create_async()
    minio_client.put_object(
        bucket,
        str(linked.id),
        io.BytesIO(b"linked content"),
        length=len(b"linked content"),
    )

    # Call the audit endpoint
    resp = await authenticated_admin_client.get("/api/v1/web/resources/audit/orphans")
    assert resp.status_code == 200
    data = resp.json()
    assert "orphaned_objects" in data
    assert "orphaned_db_records" in data
    # S3 orphan should be detected
    assert s3_orphan_key in data["orphaned_objects"]
    # DB orphan should be detected
    assert str(db_orphan.id) in data["orphaned_db_records"]
    # Linked resource should not be reported as orphan
    assert str(linked.id) not in data["orphaned_db_records"]
    assert str(linked.id) not in data["orphaned_objects"]


@pytest.mark.asyncio
async def test_orphan_audit_forbidden_for_non_admin(
    authenticated_async_client: AsyncClient,
) -> None:
    resp = await authenticated_async_client.get("/api/v1/web/resources/audit/orphans")
    assert resp.status_code == 403
    assert resp.json()["detail"] == "Admin access required."


@pytest.mark.asyncio
async def test_upload_resource_metadata_and_upload_file(
    authenticated_async_client: AsyncClient,
    minio_client: Minio,
    db_session: AsyncSession,
) -> None:
    url = "/api/v1/web/resources/"
    file_name = f"test_upload_{uuid.uuid4()}.txt"
    resource_type = "word_list"
    # Step 1: Request presigned upload URL
    resp = await authenticated_async_client.post(
        url,
        data={
            "file_name": file_name,
            "resource_type": resource_type,
            "detect_type": "false",
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    presigned_url = data["presigned_url"]
    resource_id = data["resource_id"]
    # Step 2: Upload a test file to MinIO using the presigned URL
    test_content = b"alpha\nbeta\ngamma\n"
    print(data)
    async with httpx.AsyncClient() as client:
        upload_resp = await client.put(
            presigned_url,
            content=test_content,
            headers={"Content-Type": "application/octet-stream"},
        )
    assert upload_resp.status_code in (200, 204)
    # Step 3: Verify the object exists in MinIO
    bucket = settings.MINIO_BUCKET
    obj = minio_client.get_object(bucket, resource_id)
    downloaded = obj.read()
    assert downloaded == test_content
    obj.close()
