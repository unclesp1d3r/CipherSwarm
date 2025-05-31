from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.hash_item import HashItemOut


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

    model_config = ConfigDict(from_attributes=True)
