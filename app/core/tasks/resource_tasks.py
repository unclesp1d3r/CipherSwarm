import asyncio

from minio.error import S3Error
from sqlalchemy import delete
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.future import select

from app.core.config import settings
from app.core.logging import logger
from app.core.services.storage_service import get_storage_service
from app.models.attack_resource_file import AttackResourceFile


async def verify_upload_and_cleanup(resource_id: str, timeout_seconds: int) -> None:
    """
    Background task to verify if the file was uploaded to MinIO. If not, delete the resource from DB.
    TODO: Upgrade to Celery when Redis is available.
    """
    # Skip background task execution in test environment
    import os

    if os.getenv("PYTEST_CURRENT_TEST") is not None or os.getenv("TESTING") == "true":
        logger.info(
            f"Skipping background task execution in test environment for resource {resource_id}"
        )
        return

    await asyncio.sleep(timeout_seconds)
    # Re-check DB in case resource was verified
    from app.db.session import sessionmanager

    # Check if resource exists and is already uploaded
    resource_obj = None
    try:
        async with sessionmanager.session() as session:
            result = await session.execute(
                select(AttackResourceFile).where(AttackResourceFile.id == resource_id)
            )
            resource_obj = result.scalar_one_or_none()
    except RuntimeError as e:
        # Session manager not initialized (likely in test context)
        logger.warning(f"Background task failed to create session: {e}")
        return

    # Early exits for already processed resources
    if not resource_obj:
        return  # Already deleted or verified
    if getattr(resource_obj, "is_uploaded", False):
        logger.info(
            f"Resource {resource_id} already marked as uploaded. Skipping cleanup."
        )
        return

    # Check if file exists in storage
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
            # Continue to deletion since file not found

        # Delete resource from DB since file doesn't exist
        try:
            async with sessionmanager.session() as session:
                await session.execute(
                    delete(AttackResourceFile).where(
                        AttackResourceFile.id == resource_id
                    )
                )
                await session.commit()
                logger.info(
                    f"Resource {resource_id} not found in MinIO, deleted from DB"
                )
        except RuntimeError as e:
            # Session manager not initialized (likely in test context)
            logger.warning(f"Background task failed to delete resource: {e}")
        except (SQLAlchemyError, OSError) as e:
            logger.error(f"Background upload verification failed: {e}")

    except (SQLAlchemyError, OSError) as e:
        logger.error(f"Background upload verification failed: {e}")
