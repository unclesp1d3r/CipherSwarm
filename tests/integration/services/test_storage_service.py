import io
import uuid

import httpx
import pytest
from minio import Minio

from app.core.config import settings
from app.core.services.storage_service import StorageService


@pytest.mark.asyncio
async def test_storage_service_presign_upload_success(minio_client: Minio) -> None:
    service = StorageService()
    bucket = settings.MINIO_BUCKET
    key = f"test-upload-{uuid.uuid4()}"
    await service.ensure_bucket_exists(bucket)
    url = service.generate_presigned_upload_url(bucket, key, expiry=60)
    assert url.startswith("http")
    # Actually upload a file using the presigned URL
    content = b"upload test content\n"
    async with httpx.AsyncClient() as client:
        resp = await client.put(
            url, content=content, headers={"Content-Type": "application/octet-stream"}
        )
    assert resp.status_code in (200, 204)
    # Verify upload
    obj = minio_client.get_object(bucket, key)
    assert obj.read() == content
    obj.close()


@pytest.mark.asyncio
async def test_storage_service_presign_upload_failures(minio_client: Minio) -> None:
    service = StorageService()
    # Failure: Nonexistent bucket (simulate by deleting bucket first)
    bucket = f"nonexistent-{uuid.uuid4()}"
    key = f"fail-upload-{uuid.uuid4()}"
    # Do not create bucket
    with pytest.raises(ConnectionError):
        service.generate_presigned_upload_url(bucket, key, expiry=60)
    # Failure: Invalid credentials
    bad_service = StorageService(access_key="bad", secret_key="bad")
    with pytest.raises(ConnectionError):
        bad_service.generate_presigned_upload_url(settings.MINIO_BUCKET, key, expiry=60)


@pytest.mark.asyncio
async def test_storage_service_presign_download_success(minio_client: Minio) -> None:
    service = StorageService()
    bucket = settings.MINIO_BUCKET
    key = f"test-download-{uuid.uuid4()}"
    await service.ensure_bucket_exists(bucket)
    content = b"download test content\n"
    minio_client.put_object(bucket, key, io.BytesIO(content), length=len(content))
    url = service.generate_presigned_download_url(bucket, key, expiry=60)
    assert url.startswith("http")
    # Download using presigned URL
    async with httpx.AsyncClient() as client:
        resp = await client.get(url)
    assert resp.status_code == 200
    assert resp.content == content


@pytest.mark.asyncio
async def test_storage_service_presign_download_failures(minio_client: Minio) -> None:
    service = StorageService()
    bucket = settings.MINIO_BUCKET
    # Failure: Nonexistent object
    key = f"missing-{uuid.uuid4()}"
    url = service.generate_presigned_download_url(bucket, key, expiry=60)
    async with httpx.AsyncClient() as client:
        resp = await client.get(url)
    assert resp.status_code in {404, 403}
    # Failure: Invalid credentials
    bad_service = StorageService(access_key="bad", secret_key="bad")
    with pytest.raises(ConnectionError):
        bad_service.generate_presigned_download_url(bucket, key, expiry=60)


@pytest.mark.asyncio
async def test_storage_service_get_file_stats_success(minio_client: Minio) -> None:
    service = StorageService()
    bucket = settings.MINIO_BUCKET
    key = f"stats-{uuid.uuid4()}"
    await service.ensure_bucket_exists(bucket)
    content = b"line1\nline2\nline3\n"
    minio_client.put_object(bucket, key, io.BytesIO(content), length=len(content))
    stats = await service.get_file_stats(bucket, key)
    assert stats["byte_size"] == len(content)
    assert stats["line_count"] == content.count(b"\n")
    assert len(str(stats["checksum"])) == 64  # SHA-256 hex


@pytest.mark.asyncio
async def test_storage_service_get_file_stats_failures(minio_client: Minio) -> None:
    service = StorageService()
    bucket = settings.MINIO_BUCKET
    # Failure: Nonexistent object
    key = f"missing-{uuid.uuid4()}"
    with pytest.raises(ConnectionError):
        await service.get_file_stats(bucket, key)
    # Failure: Invalid credentials
    bad_service = StorageService(access_key="bad", secret_key="bad")
    with pytest.raises(ConnectionError):
        await bad_service.get_file_stats(bucket, key)
