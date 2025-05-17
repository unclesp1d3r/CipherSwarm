"""Pydantic schemas for the Project model in CipherSwarm."""

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class ProjectRead(BaseModel):
    """Schema for reading project data."""

    id: int
    name: str
    description: str | None = None
    private: bool
    archived_at: datetime | None = None
    notes: str | None = None
    users: list[UUID]
    created_at: datetime
    updated_at: datetime
    model_config = ConfigDict(from_attributes=True)

    @staticmethod
    def model_post_dump(data: dict[str, Any], original: object) -> dict[str, Any]:
        # users may be a list of User objects or UUIDs; extract their UUIDs
        if hasattr(original, "users"):
            data["users"] = [
                getattr(user, "id", user) for user in getattr(original, "users", [])
            ]
        return data


class ProjectCreate(BaseModel):
    """Schema for creating a new project."""

    name: str
    description: str | None = None
    private: bool = False
    archived_at: datetime | None = None
    notes: str | None = None
    users: list[UUID] | None = None


class ProjectUpdate(BaseModel):
    """Schema for updating project data."""

    name: str | None = None
    description: str | None = None
    private: bool | None = None
    archived_at: datetime | None = None
    notes: str | None = None
    users: list[UUID] | None = None
