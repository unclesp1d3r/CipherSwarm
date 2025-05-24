from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.attack_resource_file import AttackResourceType

from .shared import PaginatedResponse


class ResourceLine(BaseModel):
    id: Annotated[
        int, Field(description="Unique line identifier (index in file or DB)")
    ]
    index: Annotated[int, Field(description="Line index (0-based)")]
    content: Annotated[str, Field(description="Content of the line")]
    valid: Annotated[
        bool,
        Field(
            description="Whether the line is valid according to resource type validation"
        ),
    ]
    error_message: Annotated[
        str | None, Field(description="Validation error message, if any")
    ] = None


class ResourceLineValidationError(BaseModel):
    line_index: Annotated[int, Field(description="Index of the line with error")]
    content: Annotated[str, Field(description="Content of the line with error")]
    valid: Annotated[bool, Field(default=False, description="Always false for errors")]
    message: Annotated[str, Field(description="Validation error message")]


class ResourceUploadMeta(BaseModel):
    file_name: Annotated[str, Field(description="Original file name")]
    resource_type: Annotated[
        AttackResourceType, Field(description="Type of the resource")
    ]


class ResourceUploadResponse(BaseModel):
    resource_id: Annotated[UUID, Field(description="UUID of the created resource")]
    presigned_url: Annotated[str, Field(description="Presigned S3 upload URL")]
    resource: Annotated[ResourceUploadMeta, Field(description="Resource metadata")]


class ResourceBase(BaseModel):
    id: UUID
    file_name: str
    resource_type: AttackResourceType
    line_count: int | None = None
    byte_size: int | None = None
    updated_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True, extra="ignore")


class ResourcePreviewResponse(ResourceBase):
    preview_lines: list[str]
    preview_error: str | None = None
    max_preview_lines: int


class ResourceContentResponse(ResourceBase):
    content: str
    editable: bool


class WordlistItem(BaseModel):
    id: UUID
    file_name: str
    line_count: int | None = None


class WordlistDropdownResponse(BaseModel):
    wordlists: list[WordlistItem]


class RulelistItem(BaseModel):
    id: UUID
    file_name: str
    line_count: int | None = None


class RulelistDropdownResponse(BaseModel):
    rulelists: list[RulelistItem]


class ResourceLinesResponse(BaseModel):
    lines: list[ResourceLine]
    resource_id: UUID


class ResourceListItem(ResourceBase):
    pass  # Inherits all fields from ResourceBase


class AttackBasic(BaseModel):
    id: int
    name: str


class ResourceDetailResponse(ResourceBase):
    attacks: list[AttackBasic]


class ResourceListResponse(PaginatedResponse[ResourceListItem]):
    resource_type: AttackResourceType | None = None
