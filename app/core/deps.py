from uuid import UUID

from fastapi import Depends, Header, HTTPException, Request, status
from fastapi.security import (
    HTTPAuthorizationCredentials,
    HTTPBearer,
    OAuth2PasswordBearer,
)
from fastapi.security.utils import get_authorization_scheme_param
from jose import JWTError, jwt
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.core.security import ALGORITHM
from app.db.session import get_db
from app.models.agent import Agent
from app.models.user import User

security = HTTPBearer()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/jwt/login")


async def get_current_agent(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> Agent:
    """Get the current authenticated agent."""
    try:
        token = credentials.credentials
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        agent_id: int | None = payload.get("sub")
        if agent_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
            )
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        ) from e

    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()

    if not agent:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Agent not found",
        )

    return agent


async def get_current_agent_v1(
    authorization: str = Header(..., alias="Authorization"),
    db: AsyncSession = Depends(get_db),
) -> Agent:
    """Get the current authenticated agent for v1 API (token lookup, not JWT)."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
        )
    token = authorization.removeprefix("Bearer ").strip()
    result = await db.execute(select(Agent).filter(Agent.token == token))
    agent = result.scalar_one_or_none()
    if not agent:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid agent token",
        )
    return agent


async def get_current_user(
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> User:
    """Get the current authenticated user from JWT token or cookie."""
    cookie_token = request.cookies.get("access_token")
    if cookie_token:
        jwt_token = cookie_token
    else:
        # Try Authorization header (Bearer)
        auth = request.headers.get("Authorization")
        scheme, param = get_authorization_scheme_param(auth)
        if scheme.lower() == "bearer" and param:
            jwt_token = param
        else:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Not authenticated",
            )
    try:
        payload = jwt.decode(jwt_token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str | None = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
            )
        user_uuid = UUID(user_id)
    except (JWTError, ValueError) as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        ) from e

    result = await db.execute(
        select(User)
        .where(User.id == user_uuid)
        .options(selectinload(User.project_associations))
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User not found or not authorized",
        )
    if not getattr(user, "is_active", True):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user",
        )
    return user


async def get_current_user_from_api_key(
    authorization: str = Header(None),
    db: AsyncSession = Depends(get_db),
) -> tuple[User, bool]:
    """
    Extract and validate API key from Authorization header.
    Returns tuple of (user, is_readonly_key).
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
        )

    api_key = authorization.replace("Bearer ", "").strip()

    # Validate format: cst_<uuid>_<random>
    if not api_key.startswith("cst_"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key format",
        )

    # Look up user by either api_key_full or api_key_readonly
    result = await db.execute(
        select(User)
        .where(or_(User.api_key_full == api_key, User.api_key_readonly == api_key))
        .options(selectinload(User.project_associations))
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )

    if not getattr(user, "is_active", True):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user",
        )

    # Determine if this is a readonly key
    is_readonly = user.api_key_readonly == api_key

    return user, is_readonly


def require_write_access(
    user_and_readonly: tuple[User, bool] = Depends(get_current_user_from_api_key),
) -> User:
    """Dependency that ensures non-readonly access."""
    user, is_readonly = user_and_readonly
    if is_readonly:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Read-only API key cannot perform write operations",
        )
    return user


def get_current_control_user(
    user_and_readonly: tuple[User, bool] = Depends(get_current_user_from_api_key),
) -> User:
    """Dependency that returns current user for read operations."""
    user, _ = user_and_readonly
    return user
