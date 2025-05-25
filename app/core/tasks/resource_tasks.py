import asyncio

from minio.error import S3Error
from sqlalchemy import delete, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.logging import logger
from app.core.services.storage_service import get_storage_service
from app.models.attack_resource_file import AttackResourceFile


async def verify_upload_and_cleanup(
    resource_id: str, db: AsyncSession, timeout_seconds: int
) -> None:
    """
    Background task to verify if the file was uploaded to MinIO. If not, delete the resource from DB.
    TODO: Upgrade to Celery when Redis is available.
    """
    await asyncio.sleep(timeout_seconds)
    # Re-check DB in case resource was verified
    async with db as session:
        result = await session.execute(
            select(AttackResourceFile).where(AttackResourceFile.id == resource_id)
        )
        resource_obj = result.scalar_one_or_none()
        if not resource_obj:
            return  # Already deleted or verified
    storage_service = get_storage_service()
    bucket = settings.MINIO_BUCKET
    try:
        exists = await storage_service.bucket_exists(bucket)
        if not exists:
            logger.error(f"Bucket {bucket} does not exist")
            return  # Bucket gone, nothing to do
        # Try to get object
        try:
            obj = storage_service.client.stat_object(bucket, str(resource_id))
            if obj:
                logger.info(
                    f"File {resource_id} exists in MinIO, appears to be uploaded successfully. Skipping cleanup."
                )
                return  # File exists, do nothing
        except (S3Error, OSError) as e:
            logger.error(f"Error checking file existence in MinIO: {e}")
            return  # File not found, nothing to do
        # Delete resource from DB
        async with db as session:
            await session.execute(
                delete(AttackResourceFile).where(AttackResourceFile.id == resource_id)
            )
            await session.commit()
            logger.info(f"Resource {resource_id} not found in MinIO, deleted from DB")
    except (SQLAlchemyError, OSError) as e:
        logger.error(f"Background upload verification failed: {e}")
