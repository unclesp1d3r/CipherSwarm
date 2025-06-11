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
    created_at: datetime
    updated_at: datetime
    role: str  # User role (admin, analyst, operator)


class UserCreate(BaseModel):
    """Schema for creating a new user."""

    email: EmailStr
    name: str
    password: str


class UserCreateControl(UserCreate):
    """Schema for creating a new user via Control API with optional role."""

    role: str | None = None  # Optional role specification (admin, analyst, operator)
    is_superuser: bool | None = None  # Optional superuser flag
    is_active: bool | None = None  # Optional active flag


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

    api_key: str
    rotated_at: datetime
    message: str = "API key has been successfully rotated"


class ApiKeyInfoResponse(BaseModel):
    """Schema for API key information response."""

    has_api_key: bool
    api_key_prefix: str | None = (
        None  # First 8 characters of the API key for identification
    )
    created_at: datetime | None = None
    last_used_at: datetime | None = None  # Future enhancement - not implemented yet
    message: str
