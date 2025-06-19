import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from jose import jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(
    schemes=["bcrypt"], deprecated="auto"
)  # TODO: Move to Argon2.

ALGORITHM = "HS256"


def create_access_token(
    subject: str | Any,  # noqa: ANN401
    expires_delta: timedelta | None = None,
) -> str:
    """Create a JWT access token."""
    now = datetime.now(UTC)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode = {
        "exp": expire,
        "iat": now,  # issued at timestamp
        "jti": str(uuid.uuid4()),  # unique JWT ID for token uniqueness
        "sub": str(subject),
    }
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against a hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash a password."""
    return pwd_context.hash(password)
