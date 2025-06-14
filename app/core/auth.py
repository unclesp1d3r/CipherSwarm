from uuid import UUID

import jwt
from passlib.hash import bcrypt

from app.core.config import settings
from app.core.security import create_access_token as security_create_access_token


def hash_password(password: str) -> str:
    return bcrypt.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.verify(password, hashed)


def create_access_token(user_id: UUID) -> str:
    """Create a JWT access token.

    The token's expiration is determined by
    :data:`settings.ACCESS_TOKEN_EXPIRE_MINUTES`.
    """
    return security_create_access_token(str(user_id))


def decode_access_token(token: str) -> UUID:
    payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
    return UUID(payload["sub"])
