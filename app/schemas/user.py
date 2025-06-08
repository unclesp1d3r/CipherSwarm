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
    role: str  # User role (admin, analyst, operator)


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
    role: str | None = None  # User role (admin, analyst, operator)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class UserListItem(BaseModel):
    username: str
    email: str
    is_active: bool


class ApiKeyRotationResponse(BaseModel):
    """Schema for API key rotation response."""

    api_key_full: str
    api_key_readonly: str
    rotated_at: datetime
    message: str = "API keys have been successfully rotated"
