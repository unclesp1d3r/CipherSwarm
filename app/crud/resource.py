import logging
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.resource import Resource

logger = logging.getLogger(__name__)


class CRUDResource:
    async def get(self, db: AsyncSession, *, resource_id: int) -> Resource | None:
        """Get a resource by ID."""
        from sqlalchemy import select

        result = await db.execute(select(Resource).filter(Resource.id == resource_id))
        return result.scalar_one_or_none()

    async def get_by_type(
        self, db: AsyncSession, *, resource_type: str, skip: int = 0, limit: int = 100
    ) -> list[Resource]:
        """Get resources by type."""
        from sqlalchemy import select

        result = await db.execute(
            select(Resource)
            .filter(Resource.resource_type == resource_type)
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())

    def agent_can_access_resource(
        self,
        db: AsyncSession,  # noqa: ARG002  # pyright: ignore[reportUnusedParameter]
        *,
        agent_id: str,
        resource_id: int,
    ) -> bool:
        """Check if an agent can access a specific resource."""
        # TODO: Implement proper authorization logic
        # This would typically check:
        # - Project membership
        # - Resource permissions
        # - Agent capabilities
        # For now, return True to allow access
        logger.info(
            f"Checking resource access for agent {agent_id} and resource {resource_id}"
        )
        return True

    async def generate_presigned_url(
        self, db: AsyncSession, *, resource_id: int, expires_at: datetime
    ) -> str:
        """Generate a presigned URL for resource download."""
        # Validate expires_at is timezone-aware
        if expires_at.tzinfo is None:
            raise ValueError("expires_at must be timezone-aware (tzinfo cannot be None)")

        # Validate expires_at is in the future
        now = datetime.now(timezone.utc)
        if expires_at <= now:
            raise ValueError(f"expires_at must be in the future, got {expires_at.isoformat()} (current time: {now.isoformat()})")

        # Get the resource and validate it exists
        resource = await self.get(db=db, resource_id=resource_id)
        if not resource:
            raise ValueError(f"Resource {resource_id} not found")

        # TODO: Implement actual presigned URL generation with MinIO/S3
        # This would typically:
        # - Connect to MinIO/S3
        # - Generate a presigned URL with expiration
        # - Return the URL

        # Placeholder URL - in real implementation this would be a MinIO/S3 presigned URL
        presigned_url = f"https://storage.example.com/resources/{resource_id}?expires={expires_at.isoformat()}"
        
        # Log non-sensitive metadata at info level
        logger.info(
            f"Generated presigned URL for resource {resource_id}, expires at {expires_at.isoformat()}"
        )
        
        # Log full URL only at debug level
        logger.debug(f"Full presigned URL: {presigned_url}")
        
        return presigned_url


resource = CRUDResource()
