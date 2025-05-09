from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr


class UserRead(BaseModel):
    """Schema for reading user data."""

    id: UUID
    email: EmailStr
    name: str
    is_active: bool
    is_superuser: bool
    is_verified: bool
    created_at: datetime
    updated_at: datetime


class UserCreate(BaseModel):
    """Schema for creating a new user."""

    email: EmailStr
    name: str
    password: str


class UserUpdate(BaseModel):
    """Schema for updating user data."""

    email: EmailStr | None = None
    name: str | None = None
    password: str | None = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
