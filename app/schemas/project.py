"""Pydantic schemas for the Project model in CipherSwarm."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class ProjectRead(BaseModel):
    """Schema for reading project data."""

    id: UUID
    name: str
    description: str | None = None
    private: bool
    archived_at: datetime | None = None
    notes: str | None = None
    users: list[UUID]
    created_at: datetime
    updated_at: datetime


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
