from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.hash_item import HashItemOut


class HashListCreate(BaseModel):
    """Schema for creating a new hash list."""

    name: Annotated[
        str, Field(description="Name of the hash list", min_length=1, max_length=128)
    ]
    description: Annotated[
        str | None, Field(description="Description of the hash list", max_length=512)
    ] = None
    project_id: Annotated[int, Field(description="Project ID", gt=0)]
    hash_type_id: Annotated[int, Field(description="Hash type ID", gt=0)]
    is_unavailable: Annotated[
        bool, Field(description="True if the hash list is not yet ready for use")
    ] = False


class HashListOut(BaseModel):
    id: Annotated[int, Field(description="Unique identifier for the hash list")]
    name: Annotated[str, Field(description="Name of the hash list")]
    description: Annotated[
        str | None, Field(description="Description of the hash list")
    ] = None
    project_id: Annotated[int, Field(description="Project ID")]
    hash_type_id: Annotated[int, Field(description="Hash type ID")]
    is_unavailable: Annotated[
        bool, Field(description="True if the hash list is not yet ready for use")
    ]
    items: Annotated[list[HashItemOut], Field(description="Hashes in the hash list")]
    created_at: Annotated[datetime, Field(description="Creation timestamp")]
    updated_at: Annotated[datetime, Field(description="Last update timestamp")]

    model_config = ConfigDict(from_attributes=True)
