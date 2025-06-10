"""
Control API users endpoints.

The Control API uses API key authentication and offset-based pagination.
All responses are JSON format.
Error responses must follow RFC9457 format.
"""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Path, Query, status
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.control.utils import (
    offset_to_page_conversion,
)
from app.core.authz import user_can
from app.core.control_exceptions import (
    InsufficientPermissionsError,
    UserConflictError,
    UserNotFoundError,
)
from app.core.deps import get_current_control_user
from app.core.services.user_service import (
    PaginatedUserList,
    create_user_service,
    get_user_by_id_service,
    list_users_paginated_service,
)
from app.db.session import get_db
from app.models.user import User, UserRole
from app.schemas.shared import OffsetPaginatedResponse
from app.schemas.user import UserCreateControl, UserRead

router = APIRouter(prefix="/users", tags=["Control - Users"])


class UserListResponse(OffsetPaginatedResponse[UserRead]):
    search: str | None = None


@router.get(
    "",
    summary="List users",
    description="List users with offset-based pagination and filtering. Requires admin permissions.",
)
async def list_users(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_control_user)],
    limit: Annotated[
        int, Query(ge=1, le=100, description="Number of items to return")
    ] = 20,
    offset: Annotated[int, Query(ge=0, description="Number of items to skip")] = 0,
    search: Annotated[
        str | None,
        Query(
            description="Search users by name or email (case-insensitive partial match)"
        ),
    ] = None,
) -> UserListResponse:
    """
    List users with offset-based pagination and filtering.

    Requires admin permissions to access user management functionality.
    Supports searching by name or email with case-insensitive partial matching.
    """
    # Check permissions - user must be superuser or have system read_users permission
    if not (
        current_user.is_superuser or user_can(current_user, "system", "read_users")
    ):
        raise InsufficientPermissionsError(
            detail="Admin permissions required to list users"
        )

    # Convert offset-based pagination to page-based for existing service
    page, page_size = offset_to_page_conversion(offset, limit)

    # Use existing paginated service
    paginated_result: PaginatedUserList = await list_users_paginated_service(
        db=db, page=page, page_size=page_size, search=search
    )

    # Convert back to offset-based response format
    return UserListResponse(
        items=paginated_result.items,
        total=paginated_result.total,
        limit=limit,
        offset=offset,
    )


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    summary="Create user",
    description="Create a new user. Requires admin permissions.",
)
async def create_user(
    user_data: UserCreateControl,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_control_user)],
) -> UserRead:
    """
    Create a new user.

    Requires admin permissions to create users.
    Automatically generates an API key for the new user.
    """
    # Check permissions - user must be superuser or have system create_users permission
    if not (
        current_user.is_superuser or user_can(current_user, "system", "create_users")
    ):
        raise InsufficientPermissionsError(
            detail="Admin permissions required to create users"
        )

    # Parse and validate role if provided
    role = UserRole.ANALYST  # Default role
    if user_data.role:
        try:
            role = UserRole(user_data.role)
        except ValueError as err:
            raise UserConflictError(
                detail=f"Invalid role '{user_data.role}'. Valid roles are: {', '.join([r.value for r in UserRole])}"
            ) from err

    # Set flags with defaults
    is_superuser = (
        user_data.is_superuser if user_data.is_superuser is not None else False
    )
    is_active = user_data.is_active if user_data.is_active is not None else True

    try:
        # Use existing service to create user
        from app.schemas.user import UserCreate

        base_user_data = UserCreate(
            email=user_data.email,
            name=user_data.name,
            password=user_data.password,
        )

        return await create_user_service(
            db=db,
            user_in=base_user_data,
            role=role,
            is_superuser=is_superuser,
            is_active=is_active,
        )
    except ValueError as err:
        raise UserConflictError(detail=str(err)) from err


@router.get(
    "/{user_id}",
    summary="Get user by ID",
    description="Get user details by ID. Requires admin permissions.",
)
async def get_user(
    user_id: Annotated[UUID, Path(description="User ID")],
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_control_user)],
) -> UserRead:
    """
    Get user details by ID.

    Requires admin permissions to access user management functionality.
    Returns detailed information about a specific user.
    """
    # Check permissions - user must be superuser or have system read_users permission
    if not (
        current_user.is_superuser or user_can(current_user, "system", "read_users")
    ):
        raise InsufficientPermissionsError(
            detail="Admin permissions required to view user details"
        )

    try:
        return await get_user_by_id_service(db=db, user_id=user_id)
    except NoResultFound as err:
        raise UserNotFoundError(
            detail=f"User with ID '{user_id}' not found in database"
        ) from err
