from collections.abc import AsyncGenerator
from datetime import timedelta

from loguru import logger
from minio import Minio
from minio.error import S3Error

from app.core.config import settings


class StorageService:
    def __init__(
        self,
        endpoint_url: str | None = None,
        access_key: str | None = None,
        secret_key: str | None = None,
        secure: bool | None = None,
        region: str | None = None,
    ) -> None:
        self.endpoint_url = endpoint_url or settings.MINIO_ENDPOINT
        self.access_key = access_key or settings.MINIO_ACCESS_KEY
        self.secret_key = secret_key or settings.MINIO_SECRET_KEY

        if secure is None:
            self.secure = self.endpoint_url.startswith("https://")
        else:
            self.secure = secure

        self.region = (
            region or settings.MINIO_REGION
        )  # Optional, defaults to None if not in settings

        self._client: Minio | None = None

    @property
    def client(self) -> Minio:
        if self._client is None:
            minio_host_port = self.endpoint_url
            try:
                self._client = Minio(
                    minio_host_port,
                    access_key=self.access_key,
                    secret_key=self.secret_key,
                    secure=self.secure,
                    region=self.region,  # Pass region if provided
                )
                # Perform a simple check to ensure connectivity
                self._client.list_buckets()  # This will raise S3Error if connection fails
                logger.info(
                    f"MinIO client initialized for endpoint: {self.endpoint_url}, secure: {self.secure}"
                )
            except S3Error as e:
                logger.error(
                    f"Failed to initialize MinIO client for {self.endpoint_url}: {e}"
                )
                raise ConnectionError(
                    f"Could not connect to MinIO at {self.endpoint_url}: {e}"
                ) from e
            except Exception as e:
                logger.error(
                    f"An unexpected error occurred during MinIO client initialization for {self.endpoint_url}: {e}"
                )
                raise ConnectionError(
                    f"Unexpected error connecting to MinIO at {self.endpoint_url}: {e}"
                ) from e

        return self._client

    async def list_objects(self, bucket_name: str) -> AsyncGenerator[str]:
        """Lists object names in the specified bucket."""
        try:
            objects = self.client.list_objects(bucket_name, recursive=True)
            for obj in objects:
                if obj.object_name is not None:
                    yield obj.object_name
        except S3Error as e:
            logger.error(f"Error listing objects in bucket {bucket_name}: {e}")
            # Depending on desired error handling, you might re-raise or yield nothing
            raise ConnectionError(
                f"Could not list objects in bucket {bucket_name}: {e}"
            ) from e

    async def bucket_exists(self, bucket_name: str) -> bool:
        """Checks if a bucket exists."""
        try:
            return self.client.bucket_exists(bucket_name)
        except S3Error as e:
            logger.error(f"Error checking if bucket {bucket_name} exists: {e}")
            raise ConnectionError(
                f"Could not check bucket existence for {bucket_name}: {e}"
            ) from e

    async def ensure_bucket_exists(self, bucket_name: str) -> None:
        """Ensures a bucket exists, creates it if not."""
        if not await self.bucket_exists(bucket_name):
            try:
                self.client.make_bucket(bucket_name, location=self.region)
                logger.info(
                    f"Bucket '{bucket_name}' created successfully in region '{self.region}'."
                )
            except S3Error as e:
                logger.error(f"Error creating bucket {bucket_name}: {e}")
                raise ConnectionError(
                    f"Could not create bucket {bucket_name}: {e}"
                ) from e
        else:
            logger.debug(f"Bucket '{bucket_name}' already exists.")

    def generate_presigned_upload_url(
        self, bucket_name: str, object_name: str, expiry: int = 3600
    ) -> str:
        """Generate a presigned URL for uploading an object to the specified bucket."""
        try:
            url = self.client.presigned_put_object(
                bucket_name, object_name, expires=timedelta(seconds=expiry)
            )
            logger.info(
                f"Generated presigned upload URL for {bucket_name}/{object_name}"
            )
        except S3Error as e:
            logger.error(
                f"Error generating presigned upload URL for {bucket_name}/{object_name}: {e}"
            )
            raise ConnectionError(
                f"Could not generate presigned upload URL: {e}"
            ) from e
        else:
            return url


def get_storage_service() -> StorageService:
    return StorageService()
