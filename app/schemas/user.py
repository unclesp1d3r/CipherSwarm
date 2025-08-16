from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserRead(BaseModel):
    """Schema for reading user data including system-generated fields."""

    id: Annotated[
        UUID,
        Field(
            description="Unique user identifier assigned by the system.",
            examples=["123e4567-e89b-12d3-a456-426614174000"],
        ),
    ]
    email: Annotated[
        EmailStr,
        Field(
            description="User's email address. Must be unique across the system.",
            examples=["admin@example.com", "analyst@corp.local"],
        ),
    ]
    name: Annotated[
        str,
        Field(
            description="User's full display name.",
            examples=["John Smith", "Jane Doe", "Security Admin"],
        ),
    ]
    is_active: Annotated[
        bool,
        Field(
            description="Whether the user account is active and can authenticate.",
            examples=[True, False],
        ),
    ]
    is_superuser: Annotated[
        bool,
        Field(
            description="Whether the user has superuser privileges with system-wide access.",
            examples=[False, True],
        ),
    ]
    created_at: Annotated[
        datetime,
        Field(
            description="Timestamp when the user account was created.",
            examples=["2024-01-01T12:00:00Z"],
        ),
    ]
    updated_at: Annotated[
        datetime,
        Field(
            description="Timestamp when the user account was last modified.",
            examples=["2024-01-01T15:30:00Z"],
        ),
    ]
    role: Annotated[
        str,
        Field(
            description="User's role determining access permissions. Options: admin, analyst, operator.",
            examples=["admin", "analyst", "operator"],
        ),
    ]

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "id": "123e4567-e89b-12d3-a456-426614174000",
                "email": "admin@example.com",
                "name": "System Administrator",
                "is_active": True,
                "is_superuser": True,
                "created_at": "2024-01-01T12:00:00Z",
                "updated_at": "2024-01-01T15:30:00Z",
                "role": "admin",
            }
        }
    )


class UserCreate(BaseModel):
    """Schema for creating a new user account."""

    email: Annotated[
        EmailStr,
        Field(
            description="User's email address. Must be unique and will be used for authentication.",
            examples=["newuser@example.com", "analyst@corp.local"],
        ),
    ]
    name: Annotated[
        str,
        Field(
            description="User's full display name.",
            min_length=1,
            max_length=255,
            examples=["John Smith", "Jane Doe"],
        ),
    ]
    password: Annotated[
        str,
        Field(
            description="User's password. Must meet complexity requirements (min 8 chars, mixed case, numbers).",
            min_length=8,
            examples=["SecurePass123!", "MyStr0ngP@ssw0rd"],
        ),
    ]

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "email": "newuser@example.com",
                "name": "New User",
                "password": "SecurePass123!",
            }
        }
    )


class UserCreateControl(UserCreate):
    """Schema for creating a new user via Control API with additional administrative options."""

    role: Annotated[
        str | None,
        Field(
            description="User role to assign. Options: admin, analyst, operator. Defaults to 'operator'.",
            examples=["admin", "analyst", "operator"],
        ),
    ] = None
    is_superuser: Annotated[
        bool | None,
        Field(
            description="Whether to grant superuser privileges. Only available to admin users.",
            examples=[False, True],
        ),
    ] = None
    is_active: Annotated[
        bool | None,
        Field(
            description="Whether the account should be active immediately. Defaults to True.",
            examples=[True, False],
        ),
    ] = None

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "email": "newadmin@example.com",
                "name": "New Administrator",
                "password": "AdminPass123!",
                "role": "admin",
                "is_superuser": True,
                "is_active": True,
            }
        }
    )


class UserUpdate(BaseModel):
    """Schema for updating user account information. All fields are optional."""

    email: Annotated[
        EmailStr | None,
        Field(
            description="Updated email address. Must be unique if provided.",
            examples=["updated@example.com"],
        ),
    ] = None
    name: Annotated[
        str | None,
        Field(
            description="Updated display name.",
            min_length=1,
            max_length=255,
            examples=["Updated Name"],
        ),
    ] = None
    password: Annotated[
        str | None,
        Field(
            description="New password. Must meet complexity requirements if provided.",
            min_length=8,
            examples=["NewSecurePass123!"],
        ),
    ] = None
    role: Annotated[
        str | None,
        Field(
            description="Updated user role. Options: admin, analyst, operator.",
            examples=["admin", "analyst", "operator"],
        ),
    ] = None

    model_config = ConfigDict(
        json_schema_extra={"example": {"name": "Updated User Name", "role": "analyst"}}
    )


class LoginRequest(BaseModel):
    """Schema for user authentication requests."""

    email: Annotated[
        EmailStr,
        Field(
            description="User's registered email address.",
            examples=["admin@example.com", "user@corp.local"],
        ),
    ]
    password: Annotated[
        str, Field(description="User's password.", examples=["MyPassword123!"])
    ]

    model_config = ConfigDict(
        json_schema_extra={
            "example": {"email": "admin@example.com", "password": "MyPassword123!"}
        }
    )


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
