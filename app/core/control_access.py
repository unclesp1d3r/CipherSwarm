"""
Control API access utilities.

These utilities provide helper functions for checking project access
and filtering data based on user permissions in the Control API.
They reuse the existing authorization logic from the Web UI.
"""

from typing import TYPE_CHECKING, Any

from fastapi import Depends, HTTPException, status
from sqlalchemy import Column, Select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.authz import user_can_access_project_by_id
from app.core.deps import get_current_control_user
from app.db.session import get_db

if TYPE_CHECKING:
    from app.models.user import User

__all__ = [
    "check_project_access",
    "filter_query_by_project_access",
    "get_user_accessible_projects",
    "require_project_access",
]


def get_user_accessible_projects(user: "User") -> list[int]:
    """
    Get list of project IDs that the user has access to.
    Uses the pre-loaded project_associations relationship.

    Args:
        user: User object with project_associations pre-loaded

    Returns:
        List of project IDs the user has access to
    """
    if not user.project_associations:
        return []

    return [assoc.project_id for assoc in user.project_associations]


async def check_project_access(user: "User", project_id: int, db: AsyncSession) -> bool:
    """
    Check if user has access to a specific project.
    Reuses the existing user_can_access_project_by_id function.

    Args:
        user: User object
        project_id: Project ID to check access for
        db: Database session

    Returns:
        True if user has access, False otherwise
    """
    return await user_can_access_project_by_id(user, project_id, db=db)


async def require_project_access(
    user: "User", project_id: int | None = None, db: AsyncSession | None = None
) -> None:
    """
    Require user to have project access. Raises HTTPException if not.

    Args:
        user: User object with project_associations pre-loaded
        project_id: Optional specific project to check. If None, checks if user has any project access.
        db: Database session

    Raises:
        HTTPException: 403 if user doesn't have required access
    """
    if project_id is not None and db is not None:
        # Check access to specific project
        has_access = await check_project_access(user, project_id, db)
        if not has_access:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"User does not have access to project {project_id}",
            )
    else:
        # Check if user has access to any projects
        accessible_projects = get_user_accessible_projects(user)
        if not accessible_projects:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User has no project access",
            )


def filter_query_by_project_access(
    query: Select[Any],
    user: "User",
    project_id_column: Column[int],
) -> Select[Any]:
    """
    Filter a SQLAlchemy query by user's accessible projects.

    Args:
        query: Base SQLAlchemy Select query to filter
        user: User object with project_associations pre-loaded
        project_id_column: The column representing project_id in the query

    Returns:
        Filtered query that only includes user's accessible projects
    """
    accessible_projects = get_user_accessible_projects(user)
    return query.where(project_id_column.in_(accessible_projects))


# Dependency to get current user and require project access
async def require_control_user_with_project_access(
    project_id: int | None = None,
    user: "User" = Depends(get_current_control_user),
    db: AsyncSession = Depends(get_db),
) -> "User":
    """
    Dependency that gets current user and ensures they have project access.

    Args:
        project_id: Optional specific project to check access for
        user: Current authenticated user (injected)
        db: Database session (injected)

    Returns:
        User object if they have required access

    Raises:
        HTTPException: 403 if user doesn't have required access
    """
    await require_project_access(user, project_id, db)
    return user
