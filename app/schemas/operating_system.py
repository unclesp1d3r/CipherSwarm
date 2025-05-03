"""Pydantic schemas for the OperatingSystem model in CipherSwarm."""

from uuid import UUID

from pydantic import BaseModel

from app.models.operating_system import OSName


class OperatingSystemRead(BaseModel):
    """Schema for reading operating system data."""

    id: UUID
    name: OSName
    cracker_command: str


class OperatingSystemCreate(BaseModel):
    """Schema for creating a new operating system entry."""

    name: OSName
    cracker_command: str


class OperatingSystemUpdate(BaseModel):
    """Schema for updating operating system data."""

    name: OSName | None = None
    cracker_command: str | None = None
