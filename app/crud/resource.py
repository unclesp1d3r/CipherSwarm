import logging
from datetime import datetime

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
        # TODO: Implement actual presigned URL generation with MinIO/S3
        # This would typically:
        # - Connect to MinIO/S3
        # - Generate a presigned URL with expiration
        # - Return the URL

        # For now, return a placeholder URL
        resource = await self.get(db=db, resource_id=resource_id)
        if not resource:
            raise ValueError(f"Resource {resource_id} not found")

        # Placeholder URL - in real implementation this would be a MinIO/S3 presigned URL
        presigned_url = f"https://storage.example.com/resources/{resource_id}?expires={expires_at.isoformat()}"
        logger.info(
            f"Generated presigned URL for resource {resource_id}: {presigned_url}"
        )
        return presigned_url


resource = CRUDResource()
