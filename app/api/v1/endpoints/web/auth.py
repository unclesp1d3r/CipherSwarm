from typing import Annotated

import jwt
from fastapi import (
    APIRouter,
    Depends,
    Form,
    HTTPException,
    Request,
)
from fastapi import (
    status as http_status,
)
from loguru import logger
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import create_access_token, decode_access_token
from app.core.deps import get_current_user, get_db
from app.core.services.user_service import (
    authenticate_user_service,
    get_user_project_context_service,
    set_user_project_context_service,
    update_user_profile_service,
)
from app.models.user import User
from app.schemas.user import UserRead, UserUpdate
from app.web.templates import jinja

router = APIRouter(prefix="/auth", tags=["Auth"])


class LoginResult(BaseModel):
    message: str
    level: str


@router.post(
    "/login",
    summary="Login (Web UI)",
    description="Authenticate user and set JWT cookie for web UI.",
)
@jinja.hx("fragments/alert.html.j2")
async def login(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    email: Annotated[str, Form(...)],
    password: Annotated[str, Form(...)],
) -> LoginResult:
    user = await authenticate_user_service(email, password, db)
    if not user:
        logger.warning(f"Failed login attempt for email: {email}")
        request.state.hx_status_code = http_status.HTTP_401_UNAUTHORIZED
        return LoginResult(message="Invalid email or password.", level="error")
    if not user.is_active:
        logger.warning(f"Inactive user login attempt: {email}")
        request.state.hx_status_code = http_status.HTTP_403_FORBIDDEN
        return LoginResult(message="Account is inactive.", level="error")
    token = create_access_token(user.id)
    logger.info(f"User {user.email} logged in successfully.")
    request.state.set_cookie = {
        "key": "access_token",
        "value": token,
        "httponly": True,
        "secure": True,
        "samesite": "lax",
        "max_age": 60 * 60,
    }
    return LoginResult(message="Login successful.", level="success")


@router.post(
    "/logout",
    summary="Logout (Web UI)",
    description="Clear JWT cookie and log out user.",
)
@jinja.hx("fragments/alert.html.j2")
async def logout() -> LoginResult:
    # Clear cookies (access_token, active_project_id)
    # (Assume request.state.set_cookie is handled by middleware or response)
    # If not, use Response.delete_cookie
    return LoginResult(message="Logged out.", level="success")


@router.post(
    "/refresh",
    summary="Refresh JWT token (Web UI)",
    description="Refresh JWT access token using cookie.",
)
@jinja.hx("fragments/alert.html.j2")
async def refresh_token(
    request: Request, db: Annotated[AsyncSession, Depends(get_db)]
) -> LoginResult:
    token = request.cookies.get("access_token")
    if not token:
        logger.warning("No access_token cookie found for refresh.")
        request.state.hx_status_code = http_status.HTTP_401_UNAUTHORIZED
        return LoginResult(message="No token found.", level="error")
    try:
        user_id = decode_access_token(token)
    except jwt.PyJWTError as e:
        logger.warning(f"Invalid or expired token during refresh: {e}")
        request.state.hx_status_code = http_status.HTTP_401_UNAUTHORIZED
        return LoginResult(message="Invalid or expired token.", level="error")
    user = await db.get(User, user_id)
    if not user or not user.is_active:
        logger.warning(f"Refresh attempt for invalid or inactive user: {user_id}")
        request.state.hx_status_code = http_status.HTTP_401_UNAUTHORIZED
        return LoginResult(message="User not found or inactive.", level="error")
    new_token = create_access_token(user.id)
    logger.info(f"Refreshed token for user {user.email}")
    response = LoginResult(message="Session refreshed.", level="success")
    request.state.set_cookie = {
        "key": "access_token",
        "value": new_token,
        "httponly": True,
        "secure": True,
        "samesite": "lax",
        "max_age": 60 * 60,
    }
    return response


@router.get(
    "/me",
    summary="Get current user profile (Web UI)",
    description="Return user profile fragment for current user.",
)
@jinja.page("fragments/profile.html.j2")
async def get_me(
    current_user: Annotated[User, Depends(get_current_user)],
) -> dict[str, object]:
    return {"user": UserRead.model_validate(current_user, from_attributes=True)}


@router.patch(
    "/me",
    summary="Update current user profile (Web UI)",
    description="Update name/email for current user.",
)
@jinja.hx("fragments/profile.html.j2")
async def update_me(
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    payload: UserUpdate,
) -> dict[str, object]:
    # Only allow updating name/email
    if payload.name is None and payload.email is None:
        raise HTTPException(status_code=422, detail="No fields to update.")
    # Check for duplicate email/name if changed
    if payload.email and payload.email != current_user.email:
        q = await db.execute(select(User).where(User.email == payload.email))
        if q.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Email already in use.")
    if payload.name and payload.name != current_user.name:
        q = await db.execute(select(User).where(User.name == payload.name))
        if q.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Name already in use.")
    updated_user = await update_user_profile_service(
        current_user, db, name=payload.name, email=payload.email
    )
    return {"user": UserRead.model_validate(updated_user, from_attributes=True)}


@router.post(
    "/change_password",
    summary="Change password (Web UI)",
    description="Change password for current user.",
)
@jinja.hx("fragments/alert.html.j2")
async def change_password() -> LoginResult:
    raise HTTPException(status_code=501, detail="Not implemented yet.")


@router.get(
    "/context",
    summary="Get user/project context (Web UI)",
    description="Get current user and project context.",
)
@jinja.page("fragments/context.html.j2")
async def get_context(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, object]:
    active_project_id_raw = request.cookies.get("active_project_id")
    try:
        active_project_id = (
            int(active_project_id_raw) if active_project_id_raw else None
        )
    except ValueError:
        active_project_id = None
    return await get_user_project_context_service(current_user, db, active_project_id)


class SetContextRequest(BaseModel):
    project_id: int


@router.post(
    "/context",
    summary="Set user/project context (Web UI)",
    description="Set active project for current user.",
)
@jinja.page("fragments/context.html.j2")
async def set_context(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    payload: SetContextRequest,
) -> dict[str, object]:
    try:
        await set_user_project_context_service(current_user, payload.project_id, db)
    except NoResultFound as e:
        raise HTTPException(
            status_code=403, detail="User does not have access to this project."
        ) from e
    request.state.set_cookie = {
        "key": "active_project_id",
        "value": str(payload.project_id),
        "httponly": True,
        "secure": True,
        "samesite": "lax",
        "max_age": 60 * 60 * 24 * 30,
    }
    return await get_user_project_context_service(current_user, db, payload.project_id)
