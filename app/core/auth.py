from uuid import UUID

import jwt
from passlib.hash import bcrypt

SECRET_KEY = "change-me-in-env"  # TODO: Load from environment variable in production


def hash_password(password: str) -> str:
    return bcrypt.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.verify(password, hashed)


def create_access_token(user_id: UUID) -> str:
    payload = {"sub": str(user_id)}
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")


def decode_access_token(token: str) -> UUID:
    payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
    return UUID(payload["sub"])
