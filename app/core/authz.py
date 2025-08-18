# pyright: reportMissingTypeStubs=false
from pathlib import Path

import casbin  # type: ignore[import-untyped]
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.logging import logger
from app.core.services.campaign_service import CampaignNotFoundError
from app.core.services.project_service import ProjectNotFoundError
from app.models.campaign import Campaign
from app.models.project import Project, ProjectUserAssociation, ProjectUserRole
from app.models.user import User, UserRole

MODEL_PATH = Path(__file__).parents[2] / "config" / "model.conf"
POLICY_PATH = Path(__file__).parents[2] / "config" / "policy.csv"


class EnforcerManager:
    """Singleton manager for Casbin enforcer."""

    _instance: casbin.Enforcer | None = None

    @classmethod
    def get_enforcer(cls) -> casbin.Enforcer:
        if cls._instance is None:
            if not MODEL_PATH.exists() or not POLICY_PATH.exists():
                raise RuntimeError(
                    f"Casbin config missing: {MODEL_PATH} or {POLICY_PATH}"
                )
            cls._instance = casbin.Enforcer(str(MODEL_PATH), str(POLICY_PATH))
        return cls._instance


def get_enforcer() -> casbin.Enforcer:
    return EnforcerManager.get_enforcer()


def user_can(user: User, resource: str, action: str) -> bool:
    # Fast path for system-level admin checks
    if resource == "system" and action == "create_users":
        return (
            getattr(user, "is_superuser", False)
            or getattr(user, "role", None) == "admin"
        )
    enforcer = get_enforcer()
    role = get_user_role(user)
    return bool(enforcer.enforce(role, resource, action))


def user_can_access_project(user: User, project: Project, action: str = "read") -> bool:
    # For now, resource is project:{project_id}
    resource = f"project:{project.id}"
    return user_can(user, resource, action)


def user_can_access_campaign(
    user: User, campaign: Campaign, action: str = "read"
) -> bool:
    # For now, resource is campaign:{campaign_id}
    resource = f"campaign:{campaign.id}"
    return user_can(user, resource, action)


async def user_can_access_project_by_id(
    user: User, project_id: int, action: str = "read", db: AsyncSession | None = None
) -> bool:
    """
    Check if user has access to project by id.
    Only allows access if:
      - user is superuser
      - user is global admin
      - user is a member of the project (via ProjectUserAssociation)
    Then checks Casbin for fine-grained permission (admin/member distinction).
    """
    if db is None:
        raise ValueError("Database session is required")
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        logger.error(f"Project {project_id} not found for user {user.id}")
        raise ProjectNotFoundError(f"Project {project_id} not found")
    # Superusers and global admins always allowed
    if user.is_superuser or user.role == UserRole.ADMIN:
        return True

    # Query project membership fresh from database to avoid stale relationship data
    association_result = await db.execute(
        select(ProjectUserAssociation).where(
            ProjectUserAssociation.user_id == user.id,
            ProjectUserAssociation.project_id == project_id,
        )
    )
    is_member = association_result.scalar_one_or_none() is not None

    if not is_member:
        return False
    # Optionally: check project-specific role for Casbin
    return user_can_access_project(user, project, action)


async def user_can_access_campaign_by_id(
    user: User, campaign_id: int, action: str = "read", db: AsyncSession | None = None
) -> bool:
    """
    Check if user has access to campaign by id.

    Args:
        user: User
        campaign_id: Campaign ID
        action: Action to check
        db: Database session
    Returns:
        bool: True if user has access to campaign, False otherwise
    """
    if db is None:
        raise ValueError("Database session is required")
    result = await db.execute(
        select(Campaign)
        .options(selectinload(Campaign.project))
        .where(Campaign.id == campaign_id)
    )
    campaign = result.scalar_one_or_none()
    if not campaign:
        raise CampaignNotFoundError(f"Campaign {campaign_id} not found")
    return user_can_access_project(user, campaign.project, action)


def get_user_role(user: User) -> str:
    # Check for superuser status
    if getattr(user, "is_superuser", False):
        return "admin"

    # Check project-specific roles
    for association in user.project_associations:
        if association.role == ProjectUserRole.admin:
            return "project_admin"

    # Default role
    return "project_user"
